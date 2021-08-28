(use joy)
(import ../art)
(use ../template)
(use ./shared)

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

(def gallery-size 5)

(defn index [request]
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
        (when (= "" (get gallery-params :tags))
          (put gallery-params :tags nil))
        (put gallery-params :page nil)
        (def href (build-uri "/gallery" gallery-params))
        [
          [:li tag " - " [:a {:href href} "Remove tag from search"]]
        ]) tags)
      ]
      ]
      )
  ]})
  )
