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
(route :get "/negotiate/:id" index/negotiate :index/negotiate)
(route :get "/view/:id" index/view :index/view)
(route :get "/gallery" index/gallery :index/gallery)

(def app (-> (handler)
             (middleware/authorization)
             (extra-methods)
             (query-string)
             (middleware/www-url-form)
             (middleware/json)
             (server-error)
             (middleware/static-files)
             (not-found)
             (logger)
             ))

(defn main [& args]
  # Stuff must be available for the runtime within main
  (initialize/initialize)
  # (gcsetinterval 4194304) # Default
  (let [port (get args 1 (or (env :port) "9000"))
        host (get args 2 (or (env :host) "localhost"))]
    (server app port host 100000000)))
