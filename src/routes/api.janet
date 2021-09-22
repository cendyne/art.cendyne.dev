(use joy)
(import ../art)
(use ./shared)
(import ../middleware)

(defn- redirect-art [art]
  @{
    :status 302
    :headers @{
      "Location" (string "/negotiate/" (get art :public-id))
    }
    :body ""
  })

(defn- public-art [art]
  (when art
    (def tags @[])
    (def files @[])
    (def art-id (get art :id))
    (each tag (art/find-tags-by-art-id art-id)
      (array/push tags (get tag :tag)))
    (each file (art/find-art-files art-id)
      (array/push files @{
        :url (string "/" (get file :path))
        :content-type (get file :content-type)
        :size (get file :size)
      }))
     @{
      :id (get art :public-id)
      :name (get art :name)
      :files files
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
    art (application/json (public-art art))
    true
    (merge (text/plain "No art found") @{:status 404})
  ))

(defn negotiate [request]
  (if-let [
    public-id (get-in request [:params :id])
    art (art/find-by-public-id public-id)
    art-id (get art :id)
    files (art/find-art-files art-id)
    files (map (fn [file] (merge file @{:filename (string "./public/" (get file :path))})) files)
    files (filter (fn [file] (file-exists? (get file :filename))) files)
    types (map (fn [file] (get file :content-type)) files)
    accept (or (get-in request [:headers "Accept"]) (get-in request [:headers "accept"]) "")
    # Add JPEG as a fallback
    accept (if (string/find "image/jpeg" accept) accept (string accept ",image/jpeg"))
    # Add PNG as a fallback
    accept (if (string/find "image/png" accept) accept (string accept ",image/png"))
    accept (map (fn [type] (get (string/split ";" type) 0)) (string/split "," accept))
    accepted (find-accepted-type types accept)
    file (get (filter (fn [file] (= accepted (get file :content-type))) files) 0)
    filename (get file :filename)
    filepath (string "/" (get file :path))
    ]
  (do
    (var content nil)
    (def etag-content (middleware/get-etag filename))
    (set content (get etag-content :content))
    (def etag (get etag-content :etag))
    (def no-match (middleware/find-no-match etag request))
    (when (and no-match (nil? content)) (set content (slurp filename)))
    (if no-match @{
      :status 200
      :body content
      :headers @{
        "Content-Type" accepted
        "Content-Location" filepath
        "ETag" etag
        "Cache-Control" "public, max-age=315360000"
        "Vary" "Accept"
      }
      :level "verbose"}
      @{:status 304 :headers @{
        "Content-Type" accepted
        "Content-Location" filepath
        "ETag" etag
        "Cache-Control" "public, max-age=315360000"
        "Vary" "Accept"
      } :level "verbose"}))
    (merge (text/plain "No art found") @{:status 404})
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
    redirect
    (merge (text/plain "No results") @{:status 404})
    true (do
      (def public-results @[])
      (each art results (array/push public-results (public-art art)))
      (application/json @{
        "result" public-results
      }))
  ))


(defn tags [request]
  (application/json @{
    "tags" (map (fn [tag] (get tag :tag)) (art/find-unique-tags))
  }))



(defn put-art-handler [request]
  (def public-id (get-in request [:body :id]))
  (def public-id (if (= :null public-id) nil public-id))
  (def name (get-in request [:body :name]))
  (def name (if (= :null name) nil name))
  (def tags (get-in request [:body :tags] []))
  (def remove-tags (get-in request [:body :remove-tags] []))
  (def user-files (get-in request [:body :files] []))
  (def user-remove-files (get-in request [:body :remove-files] []))

  # Find all files referenced
  (var err nil)
  (def files @[])
  (def remove-files @[])
  (var all-files-found true)
  (def file-not-found @[])
  (each user-file user-files
    (var path user-file)
    (when (string/has-prefix? "/" path) (set path (slice path 1)))
    (def file (art/find-file-by-path path))
    (if file
      (array/push files file)
      (do
        (set all-files-found false)
        (array/push file-not-found path)
        (set err "A file was not found")
      )))
  (each user-file user-remove-files
    (var path user-file)
    (when (string/has-prefix? "/" path) (set path (slice path 1)))
    (def file (art/find-file-by-path path))
    (unless file (log "Could not find file by path %p" path))
    (when file
      (array/push remove-files file)))
  (if (and (nil? public-id) (empty? files) (nil? err)) (do
    (set all-files-found false)
    (set err "No files were set")
    ))

  (var art nil)
  (when public-id
    (set art (art/find-by-public-id public-id)))
  (when (and public-id (nil? art))
    (set err "id not found"))
  # Update the art if it already exists
  (when (and art name (not= (get art :name) name))
    (def updated (art/update-art art {:name name}))
    (set art updated))
  (when (nil? err)
    # Find existing art
    (unless art
      (each file files
        (def art-file (art/find-file-arts (get file :id)))
        (unless (empty? art-file)
          (each af art-file
            # Associate the first art found
            (unless art
              (set art (art/find-by-id (get af :art-id)))))
          )))
    # Fallback to creating a new file
    (unless art (set art (art/create-art name)))
    # Ensure all files are linked
    (each file files
      (art/create-art-file art file)))
  # Add tags
  (when (and art (nil? err)) (each tag tags
    (def db-tag (art/create-tag tag))
    (art/create-art-tag art db-tag)))
  # Remove files
  (when (and art (nil? err))
    (each file remove-files
      (art/remove-art-file art file)))
  # Remove tags
  (when (and art (nil? err))
    (each tag remove-tags
      (art/remove-art-tag art tag)))
  # Response
  (if err
    (merge (application/json @{
      :message err
      :files-not-found file-not-found
    }) @{:status 404})
    (application/json @{
      "result" (public-art art)
    })))

(def put-art (middleware/with-authentication put-art-handler))

(defn save-file [temp-file original-file-name content-type public-path filename filesize]
  (def digest (art/digest-uploaded-file temp-file))
  (def existing-file (art/find-file-by-digest digest))
  (if existing-file
    # Don't persist to disk again if it already has been uploaded
    @{
      :original-name (get existing-file :original-name)
      :url (string "/" (get existing-file :path))
      :content-type (get existing-file :content-type)
      :digest digest
    }
    (do
      (art/write-uploaded-file temp-file filename)
      (art/create-file public-path digest content-type original-file-name filesize)
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
        [public-path filename] (art/new-file-names content-type)
        filesize (get entry :size)
        ]
        (do
          (def saved-file (save-file temp-file (get entry :filename) content-type public-path filename filesize))
          (def saved-file (merge @{:name (get entry :name)} saved-file))
          (array/push results saved-file))
          )))
  (application/json @{
    :result results
  }))

(def upload (middleware/with-authentication (middleware/file-uploads upload-handler)))


(def- unlinked-files-page-size 20)

(defn unlinked-files-handler [request]
  (def page (or (scan-number (or (get-in request [:query-string :page]) "0")) 0))
  (def offset (* page unlinked-files-page-size))
  (def results @[])
  (var next-page nil)
  (each file (art/find-unlinked-files offset unlinked-files-page-size)
    (array/push results @{
      :original-name (get file :original-name)
      :url (string "/" (get file :path))
      :content-type (get file :content-type)
      :digest (get file :digest)
    }))
  (if (= unlinked-files-page-size (length results))
    (set next-page (+ 1 page)))
  (application/json @{
    :result results
    :next-page next-page
  }))

(def unlinked-files (middleware/with-authentication unlinked-files-handler))

(defn delete-files-handler [request]
  (def user-files (get-in request [:body :files] []))
  (def files @[])
  (each user-file user-files
    (var path user-file)
    (when (string/has-prefix? "/" path) (set path (slice path 1)))
    (def file (art/find-file-by-path path))
    (if file
      (do
        (art/remove-file file)
        (array/push files file))
      (if (art/remove-unmanaged-file path)
        (do
          (array/push files @{
            :path path
          })))
      ))
  (application/json @{
    :deleted files
  }))

(def delete-files (middleware/with-authentication delete-files-handler))

(defn unmanaged-files-handler [request]
  (application/json @{
    :result (art/find-unmanaged-files)
  }))

(def unmanaged-files (middleware/with-authentication unmanaged-files-handler))

(defn delete-art-handler [request]
  (def public-id (get-in request [:params :id]))
  (def art (art/find-by-public-id public-id))
  (if art
    (do
      (art/remove-art art)
      (application/json @{
        :message "Art deleted"
      }))
    (merge (application/json @{
      :message "Art does not exist"
    }) {:status 404})))

(def delete-art (middleware/with-authentication delete-art-handler))

(defn delete-tag-handler [request]
  (def tag (get-in request [:params :tag]))
  (def tag (art/find-tag tag))
  (if tag
    (do
      (art/remove-tag tag)
      (application/json @{
        :message "Tag deleted"
      }))
    (merge (application/json @{
      :message "Tag does not exist"
    }) {:status 404})))

(def delete-tag (middleware/with-authentication delete-tag-handler))

(def- unlinked-tags-page-size 20)

(defn unlinked-tags-handler [request]
  (def page (or (scan-number (or (get-in request [:query-string :page]) "0")) 0))
  (def offset (* page unlinked-tags-page-size))
  (def results @[])
  (var next-page nil)
  (each tag (art/find-unlinked-tags offset unlinked-tags-page-size)
    (array/push results (get tag :tag)))
  (if (= unlinked-tags-page-size (length results))
    (set next-page (+ 1 page)))
  (application/json @{
    :result results
    :next-page next-page
  }))

(def unlinked-tags (middleware/with-authentication unlinked-tags-handler))
