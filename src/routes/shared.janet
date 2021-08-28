
(defn find-accepted-type [types accept]
  (var accepted nil)
  (each accepting accept
    (when (not accepted)
      (if (index-of accepting types)
        (set accepted accepting))))
  accepted)

(defn log [message & fields] (or (printf message ;fields) true))
(defn log-pass [message object] (or (printf message object) object))