(use joy)
(import json)
(import ../art)
(import ../middleware)
(import ../short-id)
(use janetls)
(use ../template)

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

(defn- log [message & fields] (or (printf message ;fields) true))

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

(defn picture [art &opt avoid-png attrs]
  (default avoid-png true)
  (default attrs {})
  (if-let [
    art-id (get art :id)
    files (art/find-art-files art-id)
    files (map (fn [file] (merge file @{
      :filename (string "./public/" (get file :path))
      :filepath (string "/" (get file :path))
      })) files)
    files (filter (fn [file] (file-exists? (get file :filename))) files)
    types (map (fn [file] (get file :content-type)) files)
    default-type (find-accepted-type types ["image/svg+xml" "image/jpeg" "image/png" "image/gif"])
    default-file (get (filter (fn [file] (= default-type (get file :content-type))) files) 0)
    default-file-id (get default-file :id)
    other-files (filter (fn [file] (and
      (not= default-file-id (get file :id))
      (or (not avoid-png) (not= "image/png" (get file :content-type)))
      )) files)
  ] [ :picture [
    (map (fn [file] [:source {
      :type (get file :content-type)
      :srcset (get file :filepath)
    }]) other-files)
    [:img (merge attrs {:src (get default-file :filepath) :alt (get art :name)})]
  ]]))

(defn- build-uri [path &opt t]
  (default t {})
  (var first true)
  (def buf (buffer))
  (buffer/push buf path)
  (each [k v] (pairs t)
    (if first (buffer/push buf "?") (buffer/push buf "&"))
    (set first false)
    (buffer/push buf (string (http/url-encode (string k)) "=" (http/url-encode (string v))))
    )
  buf)

(defn view [request] (if-let [
  public-id (get-in request [:params :id])
  art (art/find-by-public-id public-id)
  art-id (get art :id)
  pic (picture art true)
  tags (art/find-tags-by-art-id art-id)
  ] (do
    (def params @{})
    (def input-tags @{})
    (if-let [tags (get-in request [:query-string :gallery-tags])]
      (do
        (put params :tags tags)
        (each tag (string/split "," tags) (put input-tags tag true))
        ))
    (if-let [
      page (get-in request [:query-string :gallery-page])
      _ (< 0 (scan-number page))
      ] (put params :page page))
    (app-layout {
    :title (get art :name)
    :body [
      [:h1 (get art :name)]
      [:figure {:class "image-fig"}
        (picture art true {:class "image"})
      ]
      [:h2 "Tags"]
      [:ul (map (fn [tag] [:li
        (do
          (def text (get tag :tag))
          (def plus-tag (string/join (keys (merge input-tags @{text true})) ","))
          (def params (merge params @{:tags plus-tag}))
          # When adding a tag, the page number is void
          (put params :page nil)
          (def href (build-uri "/gallery" params))
          [:a {:href href} text]
        )
        ]) tags)]
      [:div {:class "view-footer"}
        [:a {:href (build-uri "/gallery" params)} "Back to Gallery"]
      ]
    ]
    }))
  (merge (app-layout {:body [:h1 "Not Found"]}) {:status 404})))

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
        (printf "File %p - Art file %p" file art-file)
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

(def gallery-size 5)

(defn gallery [request]
  (def page (or (scan-number (or (get-in request [:query-string :page]) "0")) 0))
  (def picture-params @{})
  (when (< 0 page) (put picture-params :gallery-page page))
  (var tags (get-in request [:query-string :tags]))
  (when (and tags (= 0 (length tags))) (set tags nil))
  (def gallery-params @{
    :page (if (< 0 page) page)
    :tags tags
  })
  (put picture-params :gallery-tags tags)
  (when tags (set tags (string/split "," tags)))
  (def offset (* page gallery-size))
  (def arts (if tags
    (art/find-all-by-tags tags gallery-size offset)
    (art/find-all gallery-size offset)))
  (app-layout {
    :title "Gallery"
    :body [
    (map (fn [art]
      (def id (get art :public-id))
      (def href (build-uri (string "/view/" id) picture-params))
      [:figure {:class "image-fig"}
        [:a {:href href} (picture art true {:class "image"})]
        [:figcaption [:a {:href href} (get art :name)]]
      ]) arts)
    [:p [
      (if (< 0 page) [:a {:href (build-uri "/gallery" (merge gallery-params @{:page (- page 1)}))} "Previous"] "Previous")
      " - "
      (if (= gallery-size (length arts)) [:a {:href (build-uri "/gallery" (merge gallery-params @{:page (+ page 1)}))} "Next"] "Next")
    ]]
    (when tags
      [:p "Currently searching the following tags"
      [:ul
        (map (fn [tag]
        (def minustag (filter (fn [t] (not= t tag)) tags))
        (def gallery-params (merge gallery-params @{:tags (string/join minustag ",")}))
        (when (= "" (get gallery-params :tags)) (put gallery-params :tags nil))
        (def href (build-uri "/gallery" gallery-params))
        [
          [:li tag " - " [:a {:href href} "Remove tag from search"]]
        ]) tags)
      ]
      ]
      )
  ]})
  )
