(use joy)
(import json)
(import ../art)
(import ../middleware)
(import ../short-id)
(use janetls)

(defn index [request]
  @{
    "random" "/random"
    "one or more with selected tags" "/random?tags=tag1,tag2&limit=1"
    "redirect to image" "/random?tags=tag&redirect=true"
    "all tags" "/tags"
  })

(defn- redirect-art [art] @{
    :status 302
    :headers @{
      "Location" (string "/" (get art :path))
    }
    :body ""
  })

(defn- public-art [art]
  (when art
    (def tags @[])
    (each tag (art/find-tags-by-art-id (art :id))
      (array/push tags (tag :tag)))
    @{
      :id (art :public-id)
      :fileUrl (string "/" (art :path))
      :tags tags
      :url (string "/art/" (art :public-id))
    }))

(defn get-art [request]
  (def public-id (get-in request [:params :id]))
  (var redirect false)
  (if-let [
    user-redirect (get-in request [:query-string :redirect])
    ] (if (= "true" user-redirect) (set redirect true)))
  (def art (art/find-by-public-id public-id))
  (cond
    (and redirect art) (redirect-art art)
    art (public-art art)
    true @{
      :status 404
      :body "No art found"
    }
  ))

(defn random [request]
  (var results [])
  (var limit 1)
  (var redirect false)
  (if-let [
    user-redirect (get-in request [:query-string :redirect])
    ] (if (= "true" user-redirect) (set redirect true)))
  (if-let [
    user-limit (get-in request [:query-string :limit])
    user-limit (scan-number user-limit)
    ] (set limit (min 100 user-limit)))
  # undo user limit parsing if redirect
  (if redirect (set limit 1))
  (var tags nil)
  (if-let [
    user-tags (get-in request [:query-string :tags])
    user-tags (string/split "," user-tags)
    ] (set tags user-tags))
  (cond
    tags (set results (art/find-random-by-tags tags limit))
    true (set results (art/find-random limit))
    )
  (cond
    (and redirect (> (length results) 0)) (redirect-art (get results 0))
    redirect @{
      :status 404
      :body "No results"
    }
    true (do
      (def public-results @[])
      (each art results (array/push public-results (public-art art)))
      @{
        "result" public-results
      })
  ))

(defn tags [request]
  @{
    "tags" (map (fn [tag] (get tag :tag)) (art/find-unique-tags))
  })



(defn put-art-handler [request]
  (var path (get-in request [:body :path]))
  (when (string/has-prefix? "/" path) (set path (slice path 1)))
  (def tags (get-in request [:body :tags] []))
  (def art (art/create-art path))


  (when art (each tag tags
    (def db-tag (art/create-tag tag))
    (art/create-art-tag art db-tag)))
  (if (nil? art)
    @{
      :status 400
      :body "Path not found"
    }
    @{
      "result" (public-art art)
    }))

(def put-art (middleware/with-authentication put-art-handler))


(defn- extension-of [content-type] (case content-type
  "image/png" ".png"
  "image/jpg" ".jpg"
  "image/jpeg" ".jpeg"
  "image/avif" ".avif"
  "image/svg+xml" ".svg"
  "image/gif" ".gif"
  "image/webp" ".webp"
  "image/jxl" ".jxl"
  ))

(defn save-file [temp-file original-file-name content-type public-path filename]
  (unless (os/stat "public")
    (os/mkdir "public")
    )
  (unless (os/stat "public/uploads")
    (os/mkdir "public/uploads")
    )

  (def digest (md/digest/start :sha256))
  (file/seek temp-file :set 0)
  (loop [bytes :iterate (file/read temp-file 4096)]
    (md/update digest bytes))
  (def digest (md/finish digest :base64 :url-unpadded))
  (file/seek temp-file :set 0)
  (def existing-file (art/find-file-by-digest digest))
  (if existing-file
    # Don't persist to disk again if it already has been uploaded
    @{
      :original-name (get existing-file :original-name)
      :url (string "/" (get existing-file :path))
      :content-type (get existing-file :content-type)
      :digest digest
    }
    (with [f (file/open filename :w) file/close]
      (loop [bytes :iterate (file/read temp-file 4096)]
        (file/write f bytes))
      (art/create-file public-path digest content-type original-file-name)
      @{
        :original-name original-file-name
        :url (string "/" public-path)
        :content-type content-type
        :digest digest
      })))

(defn upload-handler [request]
  (def multipart (get request :multipart-body nil))
  (def results @[])
  (when multipart
    (each entry multipart
      (if-let [
        temp-file (get entry :temp-file)
        content-type (get entry :content-type)
        extension (extension-of content-type)
        public-path (string "uploads/" (short-id/new) extension)
        filename (string "public/" public-path)
        ]
        (array/push results
          (merge
            @{:name (get entry :name)}
            (save-file temp-file (get entry :filename) content-type public-path filename))
        ))))
  @{
    :result results
  })

(def upload (middleware/with-authentication (middleware/file-uploads upload-handler)))
