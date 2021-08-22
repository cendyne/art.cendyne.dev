(use joy)
(import ./middleware)
(import ./initialize)

(import ./routes/index)


(route :get "/" index/index :index/index)
(route :get "/tags" index/tags :index/tags)
(route :get "/random" index/random :index/random)
(route :put "/art" index/put-art :index/put-art)
(route :get "/art/:id" index/get-art :index/get-art)
(route :put "/upload" index/upload :index/upload)

(defn simple-log [handler]
  (fn [request]
    (printf "Request %p" request)
    (handler request)))

(defn simple-answer [request]
  @{
    :status 200
    :headers @{
      "Content-Type" "text/plain"
    }
    :body "hello"
  })

(def app (-> (handler)
             (middleware/with-json-body)
             (middleware/authorization)
             (extra-methods)
             (query-string)
             (middleware/www-url-form)
             (middleware/json)
             (server-error)
             (x-headers)
             (static-files)
             (not-found)
             (logger)
             ))

(defn main [& args]
  # Stuff must be available for the runtime within main
  (initialize/initialize)
  (let [port (get args 1 (or (env :port) "9001"))
        host (get args 2 (or (env :host) "localhost"))]
    (server app port host 10000000)))
