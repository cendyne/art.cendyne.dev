(use joy)
(import ./short-id)

(defn find-by-id [id]
  (as-> "select * from art where id = :id" ?
    (db/query ? {:id id})
    (get ? 0)
  ))

(defn find-by-public-id [public-id]
  (as-> "select * from art where public_id = :public" ?
    (db/query ? {:public public-id})
    (get ? 0)
  ))

(defn find-tags-by-art-id [art-id]
  (as-> "select * from art_tags at join tag t on at.tag_id = t.id where art_id = :art" ?
    (db/query ? {:art art-id})
  ))

(defn find-tag-by-art-and-tag [art-id tag]
  (as-> "select * from art_tags at join tag t on at.tag_id = t.id where at.art_id = :art and t.tag = :tag" ?
    (db/query ? {:art art-id :tag tag})
    (get ? 0)
  ))

(defn find-tag-by-art-and-tag-id [art-id tag-id]
  (as-> "select * from art_tags at where at.art_id = :art and at.tag_id = :tag" ?
    (db/query ? {:art art-id :tag tag-id})
    (get ? 0)
  ))

(defn find-all-by-tag [tag &opt limit offset]
  (default limit 1)
  (default offset 0)
  (as-> "select distinct a.* from art a join art_tags at.t on at.art_id = a.id join tag t on at.tag_id = t.id where t.tag = :tag order by a.id limit :limit offset :offset" ?
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

(defn find-tag [tag]
  (as-> "select * from tag where tag = :tag" ?
    (db/query ? {:tag tag})
    (get ? 0)
  ))

(defn find-random-by-tags [tags &opt limit]
  (default limit 1)
  (def params @{:limit limit})
  (def query (buffer))
  (var counter 1)
  (buffer/push query "select distinct a.* from art a")
  (each tag tags
    (def db-tag (find-tag tag))
    (def tablekey (string "t" counter))
    (def key (keyword "tag" counter))
    (put params key (get db-tag :id -1))
    (buffer/push query " join art_tags " tablekey " on " tablekey ".art_id = a.id and " tablekey ".tag_id = :" key)
    (set counter (+ 1 counter)))
  (buffer/push query " order by RANDOM() limit :limit")
  (as-> query ?
    (db/query ? params)
  ))

(defn find-all-by-tags [tags &opt limit offset]
  (default offset 0)
  (default limit 1)
  (def params @{:limit limit :offset offset})
  (def query (buffer))
  (var counter 1)
  (buffer/push query "select distinct a.* from art a")
  (each tag tags
    (def db-tag (find-tag tag))
    (def tablekey (string "t" counter))
    (def key (keyword "tag" counter))
    (put params key (get db-tag :id -1))
    (buffer/push query " join art_tags " tablekey " on " tablekey ".art_id = a.id and " tablekey ".tag_id = :" key)
    (set counter (+ 1 counter)))
  (buffer/push query " order by a.id limit :limit offset :offset")
  (as-> query ?
    (db/query ? params)
  ))

(defn find-unique-tags []
  (as-> "select distinct tag from tag" ?
    (db/query ? {})
  ))

(defn find-unique-tag-prefixes []
  (as-> "select distinct prefix from tag" ?
    (db/query ? {})
  ))

(defn find-unique-tag-suffixes [prefix]
  (as-> "select distinct suffix from tag where prefix = :prefix" ?
    (db/query ? {:prefix prefix})
  ))

(defn find-by-path [path]
  (as-> "select * from art a join art_file af on af.art_id = a.id join file f on af.file_id = f.id where f.path = :path" ?
    (db/query ? {:path path})
    (get ? 0)
  ))

(defn find-file-by-digest [digest]
  (as-> "select * from file where digest = :digest" ?
    (db/query ? {:digest digest})
    (get ? 0)
  ))

(defn find-file-by-path [path]
  (as-> "select * from file where path = :path" ?
    (db/query ? {:path path})
    (get ? 0)
  ))

(defn find-art-files [art-id]
  (as-> "select * from art_file af join file f on af.file_id = f.id where art_id = :art" ?
    (db/query ? {:art art-id})
  ))

(defn find-file-arts [file-id]
  (as-> "select * from art_file where file_id = :file" ?
    (db/query ? {:file file-id})
  ))

(defn find-art-file [art-id file-id]
  (as-> "select * from art_file where art_id = :art and file_id = :file" ?
    (db/query ? {:art art-id :file file-id})
    (get ? 0)
  ))

(defn create-art [name]
  (def public-id (short-id/new))
  (db/insert :art {
    :name name
    :public-id public-id
    }))

(defn create-tag [tag]
  (def existing-tag (find-tag tag))
  (if existing-tag
    existing-tag
    (do
      (var prefix nil)
      (var suffix nil)
      (when (string/find ":" tag)
        (def parts (string/split ":" tag 0 2))
        (set prefix (get parts 0))
        (set suffix (get parts 1)))
      (db/insert :tag {
        :tag tag
        :prefix prefix
        :suffix suffix
      }))))

(defn create-art-tag [art tag]
  (def public-id (short-id/new))
  (def art-id (art :id))
  (def existing-tag (find-tag-by-art-and-tag-id art-id (get tag :id)))
  (if existing-tag
    existing-tag
    (db/insert :art-tags {
      :public-id public-id
      :art-id art-id
      :tag-id (get tag :id)
      })))

(defn create-file [path digest content-type original-name size]
  (def existing-file (find-file-by-digest digest))
  (if existing-file
    existing-file
    (db/insert :file {
      :path path
      :digest digest
      :content-type content-type
      :original-name original-name
      :size size
      })))

(defn create-art-file [art file]
  (def art-id (get art :id))
  (def file-id (get file :id))
  (def existing-art-file (find-art-file art-id file-id))
  (if existing-art-file
    existing-art-file
    (db/insert :art-file {
      :art-id art-id
      :file-id file-id
      })))
