(use joy)
(import json)

(def- default-json @{
  :status 200
  :headers @{
    "Content-Type" "application/json"
  }
  :body "{}"
  })

(defn with-json-body
  [handler]
  (fn [request]
    (let [
      response (handler request)
      body (if (dictionary? response) (get response :body))
      ]
      (cond
      (= "" body) response
      body (merge (merge default-json response) @{:body (json/encode body)})
      (nil? response) default-json
      # Otherwise
      true (merge default-json @{:body (json/encode response)})
      ))))