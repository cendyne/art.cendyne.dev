(use janetls)
(use joy)
(import ../template)
(import ../csrf)
(import ../secrets)
(use ./shared)


(defn index-handler [request &opt message]
  (def session (get request :session @{}))
  (def user (get session :user))
  (template/app-layout {:body [
      [:h1 "Auth page"]
      (if user
        [
          # TODO give logout option
          [:div (string "You're authenticated as " user)]
          (form-with request {:route :authenticate/unauthenticate}
            (submit "Unauthenticate"))
        ]
        [
          (form-with request {:route :authenticate/post-form }
            (label :token "token")
            (text-field {} :token)
            (submit "Authenticate"))
        ])
      (when message [:div {:class "error"} (string message)])
    ]}))

(def index (csrf/with-masked-token index-handler (secrets/csrf-key)))

(defn handle-post [request]
  (def token (get-in request [:body :token]))
  (def session (get request :session @{}))
  (var message nil)
  (if (constant= (secrets/admin-token) token)
    (do
      (put session :user :admin)
    )
    (do
      (put session :user nil)
      (set message "This credential is invalid")
    ))
  (def add-session {:session session})
  (merge (index-handler (merge request add-session) message) add-session))

(def post-form (-> handle-post
  (csrf/with-verify-token (secrets/csrf-key))
  (csrf/with-masked-token (secrets/csrf-key))))

(defn handle-unauthenticate [request]
  (def session (get request :session @{}))
  (def user (get session :user))
  (var message nil)
  (when user
    (put session :user nil)
    (set message (string "Unauthenticated as " user))
    )
  (unless user (set message "You were not authenticated."))

  (def add-session {:session session})
  (merge (index-handler (merge request add-session) message) add-session))

(def unauthenticate (-> handle-unauthenticate
  (csrf/with-verify-token (secrets/csrf-key))
  (csrf/with-masked-token (secrets/csrf-key))))
