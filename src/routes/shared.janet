(use joy)
(import joy/router)
(import ../csrf)

(defn find-accepted-type [types accept]
  (var accepted nil)
  (each accepting accept
    (when (not accepted)
      (if (index-of accepting types)
        (set accepted accepting))))
  accepted)

(defn log [message & fields] (or (printf message ;fields) true))
(defn log-pass [message object] (or (printf message object) object))

(defn form-with
  [request &opt options & body]
  (default options {})
  (let [{:action action :route route} options
        action (if (truthy? action)
                 {:action action}
                 (if (truthy? route)
                   (router/action-for ;(if (indexed? route) route [route]))
                   {:action ""}))
        attrs (merge options action)]
    (put attrs :route nil)
    [:form attrs
      body
      (csrf/csrf-field request)
      (when (truthy? (get attrs :_method))
        (hidden-field attrs :_method))
    ]))