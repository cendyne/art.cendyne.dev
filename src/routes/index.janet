(use joy)
(import json)
(import ../art)
(use janetls)
(import ../secrets)

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
      :path (string "/" (art :path))
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

(defn put-art [request]
  (def token (get-in request [:authorization :data]))
  (if (constant= (secrets/admin-token) token)
    (do
      (def path (get-in request [:body :path]))
      (def tags (get-in request [:body :tags] []))
      (def art (art/create-art path))
      
      (when art
        (each tag tags
          (art/create-art-tag art tag)
          ))
      (if (nil? art)
        @{
          :status 400
          :body "Path not found"
        }
        @{
          "result" (public-art art)
        }))
      @{
        :status 401
        :body "Unauthorized"
      }))
  