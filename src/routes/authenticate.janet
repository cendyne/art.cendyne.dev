(use joy)
(import ../template)
(import ../csrf)
(import ../secrets)

(defn index-handler [request]
  (printf "%p" (get request :session))
  (template/app-layout {:body [
    [:h1 "Auth page"]
    (form-with request {:route :authenticate/post-form }
      (label :token "token")
      (text-field {} :token)
      (submit "Authenticate"))
  ]}))

(def index (csrf/with-masked-token index-handler (secrets/csrf-key)))



(defn handle-post [request]
  # (printf "%p" request)
  (template/app-layout {:body [
    [:h1 "Auth page"]
  ]}))

(def post-form (-> handle-post
  (csrf/with-verify-token (secrets/csrf-key))
  (csrf/with-masked-token (secrets/csrf-key))))