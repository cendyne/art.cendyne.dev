(use joy)
(import json)
(import ../art)
(import ../middleware)
(import ../short-id)
(use janetls)

(defn index [request]
  (application/json @{
    "random" "/random"
    "one or more with selected tags" "/random?tags=tag1,tag2&limit=1"
    "redirect to image" "/random?tags=tag&redirect=true"
    "all tags" "/tags"
  }))

(def- rng (math/rng))

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

(defn find-accepted-type [types accept]
  (var accepted nil)
  (each accepting accept
    (when (not accepted)
      (if (index-of accepting types)
        (set accepted accepting))))
  accepted)

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
    ]
    @{
      :status 200
      :body (slurp filename)
      :headers @{
        "Content-Type" accepted
      }
    }
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
  (def name (get-in request [:body :name]))
  (def tags (get-in request [:body :tags] []))
  (def user-files (get-in request [:body :files] []))

  # Find all files referenced
  (def files @[])
  (var all-files-found true)
  (each user-file user-files
    (var path user-file)
    (when (string/has-prefix? "/" path) (set path (slice path 1)))
    (def file (art/find-file-by-path path))
    (if file
      (array/push files file)
      (set all-files-found false)
      ))
  (if (empty? files) (set all-files-found false))

  (var art nil)
  (when public-id
    (set art (art/find-by-public-id public-id)))
  (when all-files-found
    # Find existing art
    (unless art
      (each file files
        (def art-file (art/find-file-arts (get file :id)))
        (printf "File %p - Art file %p" file art-file)
        (unless (empty? art-file)
          (each af art-file
            # Associate the first art found
            (unless art
              (set art (art/find-by-id (get af :art-id)))))
          )))
    # TODO if art and name is different, update
    # ...
    # Fallback to creating a new file
    (unless art (set art (art/create-art name)))
    # Ensure all files are linked
    (each file files
      (art/create-art-file art file)))
  # Add tags
  (when art (each tag tags
    (def db-tag (art/create-tag tag))
    (art/create-art-tag art db-tag)))
  (if (nil? art)
    (merge (text/plain "Path not found") @{:status 404})
    (application/json @{
      "result" (public-art art)
    })))

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

(defn save-file [temp-file original-file-name content-type public-path filename filesize]
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
      (art/create-file public-path digest content-type original-file-name filesize)
      (application/json @{
        :original-name original-file-name
        :url (string "/" public-path)
        :content-type content-type
        :digest digest
      }))))

(defn upload-handler [request]
  (def multipart (get request :multipart-body nil))
  (def results @[])
  (when multipart
    (each entry multipart
      (printf "%p" entry)
      (if-let [
        temp-file (get entry :temp-file)
        content-type (get entry :content-type)
        extension (extension-of content-type)
        public-path (string "uploads/" (short-id/new) extension)
        filename (string "public/" public-path)
        filesize (get entry :size)
        ]
        (array/push results
          (merge
            @{:name (get entry :name)}
            (save-file temp-file (get entry :filename) content-type public-path filename filesize))
        ))))
  (application/json @{
    :result results
  }))

(def upload (middleware/with-authentication (middleware/file-uploads upload-handler)))

(defn gallery [request]
  (def page (or (scan-number (or (get-in request [:query-string :page]) "0")) 0))
  (def arts (art/find-all 20 page))
  (text/html [:body [
    (map (fn [art]
    (def id (get art :public-id))
      [:figure
        [:img {:src (string "/negotiate/" id) :style "max-width:40em;max-height:40em;border:2px solid black;"}]
        [:figcaption [:a {:href (string "/art/" id)} (get art :name)]]
      ]) arts)
    [:p [
      (if (> 0 page) [:a {:href (string "/gallery?page=" (- page 1))} "Previous"] "Previous")
      " - "
      (if (= 20 (length arts)) [:a {:href (string "/gallery?page=" (+ page 1))} "Next"] "Next")
    ]]
  ]])
  )
