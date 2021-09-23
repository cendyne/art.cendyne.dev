(use joy)
(import sh)
(import ./secrets)
(import ./art)
(import json)
(use janetls)

(def- submit-chan (ev/thread-chan 30))

(defn submit-to-process [pending-upload]
  (def pending-upload-id (get pending-upload :id))
  (ev/give submit-chan {
    :pending-upload-id pending-upload-id
    }))

(defn- receive-processed [base-url authorization job-id]
  (def job-url (string base-url "/job/" job-id))
  (var response nil)
  (printf "GET %s" job-url)
  (def [ok job] (protect (sh/$< curl -s --header ,authorization ,job-url)))
  (unless ok
    (eprintf "NOT OK")
    (set response [:error {
      :job job
      }]))
  (when ok
    (def [ok json] (protect (json/decode job)))
    (unless ok
      (eprintf "NOT OK")
      (set response [:error {
        :job job
        :json json
        }]))
    (when ok
      (printf "OK")
      (set response [:ok json])))
  (match response
    [:ok json]
    (do

      (printf "Get json %p" (merge json {"content" "..."}))
      (try (do
        # Parse JSON
        (def public-id (get json "id"))
        (def base64 (get json "content"))
        (when (empty? base64) (error "Empty content?"))
        (def content-type (get json "content-type"))
        # Load content
        (def pending-upload-item (art/find-pending-upload-item-by-public-id public-id))
        (unless pending-upload-item (error "No pending upload item found"))
        (def pending-upload (art/find-pending-upload (get pending-upload-item :pending-upload-id)))
        (unless pending-upload (error "No pending upload found"))
        (def original-file (art/find-file (get pending-upload :file-id)))
        # Save to disk
        (printf "Writing %p bytes of base64 to disk" (length base64))
        (def {:filename filename :public-path public-path}
          (art/write-base64-file content-type base64))
        (printf "Got filename %p" filename)
        (def digest (art/digest-filename filename))
        (def original-name (get original-file :original-name))
        (def size (get (os/stat filename) :size))
        # Persist in database
        (def file (art/create-file public-path digest content-type original-name size))
        # associate to pending file
        (art/update-pending-upload-item pending-upload-item {:file-id (get file :id)})
        )
        ([err fib] (eprintf "A problem! %p" err) (debug/stacktrace fib err)))
      (printf "DELETE %s" job-url)
      (def [ok job] (protect (sh/$< curl -X DELETE -s --header ,authorization ,job-url)))
      (unless ok
        (eprintf "NOT OK")
        )
      (when ok
        (printf "Deleted")
        )
      )
    [:error err]
    (do
      (eprintf "Could not get job %s, %p" job-url err)
      )
    _ (do
      (eprintf "Could not get job %s, looks like a timeout" job-url)
      )
    )
  )

(defn- listen-lq []
  (def authorization (string "Authorization: Bearer " (secrets/lq-token)))
  (def queue (or (env :lq-processed-queue) "image-processed"))
  (def base-url (secrets/lq-base-url))
  (def queue-url (string base-url "/queues/" queue "/job"))
  (forever
    (var response nil)
    # (printf "GET %s" queue-url)
    (def [ok job] (protect (sh/$< curl -s --header ,authorization ,queue-url)))
    (unless ok
      (eprintf "NOT OK")
      (set response [:error {
        :job job
        }]))
    (when ok
      (def [ok json] (protect (json/decode job)))
      (unless ok
        (eprintf "NOT OK")
        (set response [:error {
          :job job
          :json json
          }]))
      (when ok
        # (printf "OK")
        (set response [:ok json])))
    (match response
      [:ok json]
      (do
        (var count 0)
        (each job-id (get-in json ["jobs"] [])
          # Don't make this async as it could blow up the memory
          (receive-processed base-url authorization job-id)
          (set count (+ 1 count))
          )
        (when (= 0 count)
          (ev/sleep 1))
        )
      [:error err]
      (do
        (eprintf "Could not get queue %s, %p" queue-url err)
        (eprintf "Sleeping due to error")
        (ev/sleep 5)
        )
      _ (do
        (eprintf "Could not get queue %s, looks like a timeout" queue-url)
        (eprintf "Sleeping due to error")
        (ev/sleep 60)
        )
      )
    ))

(defn- listen-submit []
  (def authorization (string "Authorization: Bearer " (secrets/lq-token)))
  (def queue (or (env :lq-processing-queue) "image-processing"))
  (def processed-queue (or (env :lq-processed-queue) "image-processed"))
  (def base-url (secrets/lq-base-url))
  (def queue-url (string base-url "/queues/" queue "/job"))
  (forever
    (def {:pending-upload-id pending-upload-id} (ev/take submit-chan))
    (def pending-upload (art/find-pending-upload pending-upload-id))
    (def file (art/find-file (get pending-upload :file-id)))
    (var response nil)
    (when file
      # (printf "GET %s" queue-url)
      (def input (buffer))
      (def content-type (get file :content-type))
      (def actions @[])
      (each item (art/find-pending-upload-item-by-pending-upload-id pending-upload-id)
        # No resize support yet.
        (def content-type (get item :content-type))
        (def arguments @[])
        # TODO handle variants
        (when (= content-type "image/jpeg")
          # Flatten the jpeg with a default background color
          (array/push arguments "-background" "#3f2e26" "-flatten" "-alpha" "off")
          )
        (def id (get item :public-id))
        (when (and content-type arguments id)
          (array/push actions {
            :output content-type
            :output-queue processed-queue
            :id id
            :arguments arguments
          })))
      (buffer/push input "{\"image\":\"")
      (def filename (string "public/" (get file :path)))

      (printf "Opening file %p" filename)
      (printf "%p" (os/stat filename))
      (with [f (file/open filename) file/close]
        # Base64 in multiples of 3 bytes
        (loop [data :iterate (file/read f 3072)]
          (buffer/push input (encoding/encode data :base64 :standard-unpadded))
        ))
      (buffer/push input "\",\"content-type\":")
      (json/encode content-type "" "" input)
      (buffer/push input ",\"actions\":")
      (json/encode actions "" "" input)
      (buffer/push input "}")

      # (printf "body %p" input)

      (def [ok job] (protect (sh/$< curl -s
        --header ,authorization
        -H "Content-Type: application/json"
        -X PUT
        --data-binary @-
        ,queue-url
        < ,input
        )))
      (unless ok
        (eprintf "NOT OK")
        (set response [:error {
          :job job
          }]))
      (when ok
        (def [ok json] (protect (json/decode job)))
        (unless ok
          (eprintf "NOT OK")
          (set response [:error {
            :job job
            :json json
            }]))
        (when ok
          # (printf "OK")
          (set response [:ok json])))
    )
    (match response
      [:ok json]
      (do
        (def [ok err] (protect
          (art/update-pending-upload pending-upload
            {:job-id (get json "id")})))
        (unless ok
          (eprintf "Error with associating upload to job %p" err)
          (eprintf "JSON: %p" json)
          )
        )
      [:error err]
      (do
        (eprintf "Could not get queue %s, %p" queue-url err)
        (eprintf "Sleeping due to error")
        (ev/sleep 5)
        )
      _ (do
        (eprintf "Could not get queue %s, looks like a timeout" queue-url)
        (eprintf "Sleeping due to error")
        (ev/sleep 60)
        )
      )
    ))


(defn background-worker []
  (ev/spawn-thread
    (secrets/load-secrets)
    (db/connect (env :database-url))
    (ev/call listen-lq)
    (ev/call listen-submit)
    )
  )
