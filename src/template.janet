(use joy)

(defn app-layout [input]
  (def {:body body :request request :title title} input)
  (default title "Art")
  (text/html
    (doctype :html5)
    [:html {:lang "en"}
     [:head
      [:title title]
      [:meta {:charset "utf-8"}]
      [:meta {:name "viewport" :content "width=device-width, initial-scale=1"}]
      [:link {:href "/gallery20210825.css" :rel "stylesheet"}]
     ]
     [:body
      [:div {:id "body"}
        [:div {:class "content"} body]
      ]
     ]]))