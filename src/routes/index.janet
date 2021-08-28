(use joy)

(defn index [request]
  (application/json @{
    "random" "/api/random"
    "one or more with selected tags" "/api/random?tags=tag1,tag2&limit=1"
    "redirect to image" "/api/random?tags=tag&redirect=true"
    "all tags" "/api/tags"
  }))
