(use janetls)
(import simple-janet-crypto :as crypto)

(defn add-token [request key]
  (def session (get request :session @{}))
  (var token (get session :csrf-token))
  (var changes @{})
  (unless token
    (set token (util/random 16)))
  {
    :masked-token (crypto/encrypt key "csrf" token)
    :token token
  })

(defn mask-token [request]
  (def result (get request :masked-token))
  (unless result (error "masked CSRF token was not included, ensure middleware is added"))
  result)

(defn verify-token [request key]
  (def session (get request :session @{}))
  (var token (get session :csrf-token))
  (unless token (error "This request does not have a token ready"))
  (var masked-token (get-in request [:body :__csrf-token]))
  (unless masked-token
    (printf "Request %p" request)
    (error "The request did not come with __csrf-token"))
  (var decrypted (crypto/decrypt key "csrf" masked-token))
  (unless decrypted (error "The __csrf-token is invalid"))
  (unless (constant= token decrypted)
    (error "The __csrf-token did not match this request"))
  request)

(defn csrf-field [request] [:input {
  :type "hidden"
  :value (mask-token request)
  :name "__csrf-token"
  }])

(defn with-masked-token [handler key] (fn [request]
  (let [
    {:masked-token masked-token :token token} (add-token request key)
    request-session (merge (get request :session {}) {:token token})
    request (merge request {:masked-token masked-token :session request-session})
    response (handler request)
    response-session (get response :session request-session)
    response-session (merge response-session {:csrf-token token})
    response (merge response {:session response-session})
    ]
    response
  )))

(defn with-verify-token [handler key] (fn [request]
  # TODO give proper error page
  (handler (verify-token request key))))
