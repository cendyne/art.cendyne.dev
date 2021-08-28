(use joy)
(import simple-janet-crypto :as crypto)

(defn- log-pass [str v] (printf str v) v)

(defn- safe-unmarshal [val]
  (unless (or (nil? val) (empty? val))
    (unmarshal val)))

(defn- decrypt-session [key str]
  (when (bytes? str)
    (crypto/decrypt key "session" str)))

(defn- decode-session [str key]
  (when (and (bytes? str)
             (truthy? key))
    (as-> str ?
          (decrypt-session key ?)
          (safe-unmarshal ?))))

(defn- session-from-request [name key request]
  (as-> (cookie request) ?
        (http/parse-cookie ?)
        (get ? name)
        (decode-session ? key)))

(defn set-cookie [response cookie]
  (def set-cookie (get-in response [:headers "Set-Cookie"]))
  (eprintf "Setting cookie %p" cookie)
  (if (indexed? set-cookie)
    (update-in response [:headers "Set-Cookie"] array/push cookie)
    (put-in response [:headers "Set-Cookie"] cookie)))

(defn- clear-cookie [name cookie-options]
  (http/cookie-string
    name
    ""
    (merge cookie-options {"Expires" "Thu, 01 Jan 1970 00:00:00 GMT"})
    ))

(defn- encrypted-cookie [name value key cookie-options]
  (http/cookie-string
      name
      (crypto/encrypt key "session" value)
      cookie-options))

(defn- session-to-cookie [key session cookie-options]
  (cond
    (not (truthy? session)) (clear-cookie "s" cookie-options)
    (empty? session) (clear-cookie "s" cookie-options)
    true (encrypted-cookie "s" (marshal session) key cookie-options)
  ))

(defn with-session
  [handler key &opt name cookie-options]
  (default name "s")
  (def cookie-options (if (dictionary? cookie-options)
                         cookie-options
                         {}))

  (def session-cookie-options {"SameSite" "Lax"
                               "HttpOnly" ""
                               "Path" "/"
                               "Secure" (when production? "")})

  (def cookie-options (->> (merge session-cookie-options cookie-options)
                           (pairs)
                           (filter |(truthy? (last $)))
                           (mapcat identity)
                           (apply struct)))

  (fn [request]
    (let [request-session (session-from-request name key request)
          before-request-session (freeze request-session)
          request (if (nil? request-session) request (merge request {:session request-session}))
          response (handler request)
          ]
      (when (truthy? response)
        (let [
          response-session (freeze (or (get response :session) (get request :session) before-request-session))
          ]
          (if (deep= response-session before-request-session)
            # No changes, leave it alone!
            response
            (set-cookie response (session-to-cookie key response-session cookie-options))
            ))))))

