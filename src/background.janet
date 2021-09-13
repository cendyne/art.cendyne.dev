(use joy)
(import sh)
(import ./secrets)
(import json)
(use janetls)

(def- submit-chan nil)

# Work needs to look like {:content-type "..." :id "..." :arguments []}
(defn submit-to-process [pending-upload-id file-id work]
  (ev/give submit-chan {
    :pending-upload-id pending-upload-id
    :file-id file-id
    :work work
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
      (printf "Get json %p" json)
      # TODO process
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
    (def {:file-id file-id :work work :pending-upload-id pending-upload-id} (ev/take submit-chan))
    (def file (db/fetch [:file file-id]))
    (def pending-upload (db/fetch [:pending-upload pending-upload-id]))
    (var response nil)
    (when file
      # (printf "GET %s" queue-url)
      (def input (buffer))
      (def content-type (get file :content-type))
      (def actions @[])
      (each work-item work
        # No resize support yet.
        (array/push actions {
          :output (get work :content-type)
          :output-queue processed-queue
          :id (get work :id)
          :arguments (get work :arguments [])
        }))
      (buffer/push input "{\"image\":\"")
      (with [f (file/open (string "public/" (get file :path)))
        (fn [fd] (file/close fd))]
        # Base64 in multiples of 3 bytes
        (loop [data :iterate (file/read f 3072)]
          (buffer/push input (encoding/encode data :base64 :standard-unpadded))
        ))
      (buffer/push input "\",\"content-type\":")
      (json/encode content-type nil nil input)
      (buffer/push input ",\"actions\":")
      (json/encode actions nil nil input)
      (buffer/push input "}")


      (def [ok job] (protect (sh/$< curl -s
        --header ,authorization
        -H "Content-Type: application/json"
        -X PUT
        --data-binary @-
        ,queue-url
        < input
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
        (printf "Got json %p" json)
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
  (set submit-chan (ev/thread-chan 30))
  (ev/spawn-thread
    (secrets/load-secrets)
    (db/connect (env :database-url))
    (ev/call listen-lq)
    (ev/call listen-submit)
    )
  )
