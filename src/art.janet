(use joy)
(import ./short-id)


(defn find-by-public-id [public-id]
  (as-> "select * from art where public_id = :public" ?
    (db/query ? {:public public-id})
    (get ? 0)
  ))

(defn find-tags-by-art-id [art-id]
  (as-> "select * from art_tags where art_id = :art" ?
    (db/query ? {:art art-id})
  ))

(defn find-tag-by-art-and-tag [art-id tag]
  (as-> "select * from art_tags where art_id = :art and tag = :tag" ?
    (db/query ? {:art art-id :tag tag})
    (get ? 0)
  ))

(defn find-all-by-tag [tag &opt limit offset]
  (default limit 1)
  (default offset 0)
  (as-> "select distinct a.* from art a join art_tags t on t.art_id = a.id where t.tag = :tag order by a.id limit :limit offset :offset" ?
    (db/query ? {:tag tag :limit limit})
  ))

(defn find-all [&opt limit offset]
  (default limit 1)
  (default offset 0)
  (as-> "select a.* from art a order by a.id limit :limit offset :offset" ?
    (db/query ? {:limit limit :offset offset})
  ))

(defn find-random [&opt limit]
  (default limit 1)
  (as-> "select a.* from art a order by RANDOM() limit :limit" ?
    (db/query ? {:limit limit})
  ))

(defn find-random-by-tags [tags &opt limit]
  (default limit 1)
  (def params @{:limit limit})
  (def query (buffer))
  (var counter 1)
  (buffer/push query "select distinct a.* from art a")
  (each tag tags
    (def tablekey (string "t" counter))
    (def key (keyword "tag" counter))
    (put params key tag)
    (buffer/push query " join art_tags " tablekey " on " tablekey ".art_id = a.id and " tablekey ".tag = :" key)
    (set counter (+ 1 counter))
    )
  (buffer/push query " order by RANDOM() limit :limit")
  (as-> query ?
    (db/query ? params)
  ))

(defn find-unique-tags []
  (as-> "select distinct tag from art_tags" ?
    (db/query ? {})
  ))

(defn find-by-path [path]
  (as-> "select * from art where path = :path" ?
    (db/query ? {:path path})
    (get ? 0)
  ))

(defn find-by-path [path]
  (as-> "select * from art where path = :path" ?
    (db/query ? {:path path})
    (get ? 0)
  ))

(defn find-file-by-digest [digest]
  (as-> "select * from file where digest = :digest" ?
    (db/query ? {:digest digest})
    (get ? 0)
  ))

(defn create-art [path]
  (def public-id (short-id/new))
  (when (os/stat (string "public/" path))
    (def existing-art (find-by-path path))
    (if existing-art
      # Return existing
      existing-art
      # Create new
      (db/insert :art {
        :public-id public-id
        :path path
        }))))

(defn create-art-tag [art tag]
  (def public-id (short-id/new))
  (def art-id (art :id))
  (def existing-tag (find-tag-by-art-and-tag art-id tag))
  (if existing-tag
    existing-tag
    (db/insert :art-tags {
      :public-id public-id
      :art-id art-id
      :tag tag
      })))

(defn create-file [path digest content-type original-name]
  (def existing-file (find-file-by-digest digest))
  (printf "Existing file? %p" existing-file)
  (if existing-file
    existing-file
    (db/insert :file {
      :path path
      :digest digest
      :content-type content-type
      :original-name original-name
      })))
