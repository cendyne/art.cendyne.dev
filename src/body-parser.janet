(use joy)
(import json)

(defn www-url-form [handler]
  (fn [request]
    (let [{:body body} request]
      (if (and body (form? request))
        (handler (merge request {
          :body (http/parse-body body)
          :original-body body
          }))
        (handler request)))))

(defn json [handler]
  (fn [request]
    (let [{:body body} request]
      (if (and body
               (json? request))
        (handler (merge request {
          :body (json/decode body true)
          :original-body body
          }))
        (handler request)))))
