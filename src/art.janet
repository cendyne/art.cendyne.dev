(use joy)
(import ./short-id)
(use janetls)

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
  (def tag (string/trim (string/ascii-lower tag)))
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
  (def tag (string/trim (string/ascii-lower tag)))
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
  (def tag (string/trim (string/ascii-lower tag)))
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

(defn find-file [id]
  (as-> "select * from file where id = :id" ?
    (db/query ? {:id id})
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

(defn find-unlinked-files [&opt offset limit]
  (default offset 0)
  (default limit 10)
  (as-> (string "select * from file where id in (select id from ("
    "select f.id, count(af.id) c from file f left join art_file af on af.file_id = f.id group by f.id"
    ") where c = 0) order by id limit :limit offset :offset") ?
    (db/query ? {:limit limit :offset offset})
  ))

(defn find-unlinked-tags [&opt offset limit]
  (default offset 0)
  (default limit 10)
  (as-> (string "select * from tag where id in ("
    "select id from ("
    "select t.id, count(at.id) c from tag t left join art_tags at on at.tag_id = t.id group by t.id"
    ") where c = 0"
    ") order by id limit :limit offset :offset") ?
    (db/query ? {:limit limit :offset offset})
  ))

(defn find-pending-upload [id]
  (as-> "select * from pending_upload where id = :id" ?
    (db/query ? {:id id})
    (get ? 0)
  ))

(defn find-pending-upload-by-public-id [public-id]
  (as-> "select * from pending_upload where public_id = :id" ?
    (db/query ? {:id public-id})
    (get ? 0)
  ))

(defn find-pending-upload-item [id]
  (as-> "select * from pending_upload_item where id = :id" ?
    (db/query ? {:id id})
    (get ? 0)
  ))

(defn find-pending-upload-item-by-public-id [public-id]
  (as-> "select * from pending_upload_item where public_id = :id" ?
    (db/query ? {:id public-id})
    (get ? 0)
  ))

(defn find-pending-upload-item-by-pending-upload-id [id]
  (as-> "select * from pending_upload_item where pending_upload_id = :id" ?
    (db/query ? {:id id})
  ))

(defn find-original-upload [id]
  (as-> "select * from original_upload where id = :id" ?
    (db/query ? {:id id})
    (get ? 0)
  ))

(defn find-original-upload-by-public-id [public-id]
  (as-> "select * from original_upload where public_id = :id" ?
    (db/query ? {:id public-id})
    (get ? 0)
  ))

(defn find-original-upload-by-file-id [file-id]
  (as-> "select * from original_upload where file_id = :id" ?
    (db/query ? {:id file-id})
    (get ? 0)
  ))

(defn create-art [name &opt original-upload]
  (def public-id (short-id/new))
  (var original-upload-id nil)
  (when original-upload
    (set original-upload-id (get original-upload :id))
    )
  (db/insert :art {
    :name name
    :public-id public-id
    :original-upload-id original-upload-id
    }))

(defn update-art [art props]
  (db/update :art art props))

(defn create-tag [tag]
  (def tag (string/trim (string/ascii-lower tag)))
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

(var- upload-path-exists nil)
(defn ensure-upload-path-exists []
  (unless upload-path-exists
    (unless (os/stat "public")
      (os/mkdir "public"))
    (unless (os/stat "public/uploads")
      (os/mkdir "public/uploads"))
    (set upload-path-exists true))
  nil)


(defn write-uploaded-file [temp-file filename]
  (ensure-upload-path-exists)
  (with [f (file/open filename :w) file/close]
    (loop [bytes :iterate (file/read temp-file 4096)]
      (file/write f bytes))))

(def- content-types {
  "image/gif" ".gif"
  "image/jpg" ".jpg"
  "image/jpeg" ".jpg"
  "image/png" ".png"
  "image/webp" ".webp"
  "image/avif" ".avif"
  "image/jxl" ".jxl"
})

(defn write-base64-file [content-type base64]
  (ensure-upload-path-exists)
  (let [ok result] (protect (do
    (def content (if content (encoding/decode content :base64)))
    (unless content (error "Content is nil"))
    (def content-type (get json "content-type"))
    (unless content-type (error "content-type is nil"))
    (def extension (get content-types content-type))
    (unless extension (errorf "extension not found for content type %p" content-type))
    (def public-path (string "uploads/" (short-id/new) extension))
    (def filename (string "public/" public-path))
    (with [f (file/open filename :w) file/close]
      (file/write f content))
    {:filename filename :public-path public-path})))
  (if ok result))

(defn digest-uploaded-file [temp-file]
  (def digest (md/digest/start :sha256))
  (file/seek temp-file :set 0)
  (loop [bytes :iterate (file/read temp-file 4096)]
    (md/update digest bytes))
  (def digest (md/finish digest :base64 :url-unpadded))
  (file/seek temp-file :set 0)
  digest)

(defn digest-filename [filename]
  (def digest (md/digest/start :sha256))
  (with [f (file/open filename :w) file/close]
    (loop [bytes :iterate (file/read f 4096)]
      (md/update digest bytes)))
  (def digest (md/finish digest :base64 :url-unpadded))
  digest)

(defn remove-art-tag [art tag]
  (def art-id (get art :id))
  (def tag (if (dictionary? tag) tag (find-tag tag)))
  (def tag-id (get tag :id))
  (as-> "select * from art_tags where art_id = :art and tag_id = :tag" ?
    (db/query ? {:art art-id :tag tag-id})
    (each art-tag ?
      (db/delete :art-tags (get art-tag :id)))))

(defn remove-art-file [art file]
  (def art-id (get art :id))
  (def file (if (dictionary? file) file (find-file-by-path file)))
  (def file-id (get file :id))
  (as-> "select * from art_file where art_id = :art and file_id = :file" ?
    (db/query ? {:art art-id :file file-id})
    (each art-file ?
      (db/delete :art-file (get art-file :id)))))

(defn remove-art [art]
  (def art-id (get art :id))
  (as-> "select * from art_file where art_id = :art" ?
      (db/query ? {:art art-id})
      (each art-file ?
        (db/delete :art-file (get art-file :id))))
  (as-> "select * from art_tags where art_id = :art" ?
      (db/query ? {:art art-id})
      (each art-tag ?
        (db/delete :art-tags (get art-tag :id))))
  (db/delete :art art-id))

(defn remove-tag [tag]
  (def tag-id (get tag :id))
  (as-> "select * from art_tags where tag_id = :tag" ?
      (db/query ? {:tag tag-id})
      (each art-tag ?
        (db/delete :art-tags (get art-tag :id))))
  (db/delete :tag tag-id))

(defn remove-file [file]
  (def file-id (get file :id))
  (as-> "select * from art_file where file_id = :file" ?
      (db/query ? {:file file-id})
      (each art-file ?
        (printf "Dleeting art-file %p" art-file)
        (db/delete :art-file (get art-file :id))))
  (def filename (string "public/" (get file :path)))
  (try
    (do
      (printf "Deleting file %p" filename)
      (if (os/stat filename)
        (os/rm filename)
        (printf "File does not exist")))
    ([err] (eprintf "Could not delete file %p: %p" file err)))
  (db/delete :file file-id))

(defn extension-of [content-type] (case content-type
  "image/png" ".png"
  "image/jpg" ".jpg"
  "image/jpeg" ".jpeg"
  "image/avif" ".avif"
  "image/svg+xml" ".svg"
  "image/gif" ".gif"
  "image/webp" ".webp"
  "image/jxl" ".jxl"
  (errorf "Unsupported %p" content-type)
  ))


(defn new-file-names [content-type]
  (def extension (extension-of content-type))
  (def public-path (string "uploads/" (short-id/new) extension))
  (def filename (string "public/" public-path))
  [public-path filename])

(defn find-unmanaged-files [&opt limit]
  (default limit 10)
  (var remaining limit)
  (def files (os/dir "public/uploads/"))
  (def results @[])
  (while (and (< 0 remaining) (not (empty? files)))
    (def basename (array/pop files))
    (def public-path (string "uploads/" basename))
    (def filename (string "public/" public-path))

    (def file (find-file-by-path public-path))
    (unless file
      (array/push results public-path)
      (set remaining (- remaining 1))))
  results)

(defn remove-unmanaged-file [public-path]
  (def filename (string "public/" public-path))
  (if (os/stat filename)
    (do (os/rm filename) true)
    false))

(defn update-pending-upload [upload props]
  (db/update :pending-upload upload props))

(defn update-pending-upload-item [item props]
  (db/update :pending-upload-item item props))

(def- variant-grammar (peg/compile ~{
  :k (capture (some :w))
  :v (capture (any (if-not (+ "," ":") 1)))
  :p (* :k (+ (* ":" :v) (constant true)))
  :list (? (* :p (any (* "," :p))))
  :main (cmt :list ,table)
  }))

(defn parse-variant [str]
  (var result nil)
  (when str
    (set result (get (peg/match x str) 0)))
  result)

(defn encode-variant [tbl]
  (def result (buffer))
  (var second false)
  (each [k v] (sort (pairs tbl))
    (when second (buffer/push result ","))
    (buffer/push result (string k))
    (set second true)
    (when (not= v true)
      (buffer/push result ":" (string v))
      ))
  result)

(defn create-pending-upload [file &opt original-upload]
  (def file-id (get file :id))
  (def public-id (short-id/new))
  (var original-upload-id nil)
  (when original-upload
    (set original-upload-id (get original-upload :id))
    )
  (db/insert :pending-upload {
    :public-id public-id
    :file-id file-id
    :original-upload-id original-upload-id
    }))

(defn create-pending-upload-item [pending-upload content-type &opt variant]
  (default variant @{})
  (def variant (encode-variant variant))
  (def public-id (short-id/new))
  (def pending-upload-id (get pending-upload :id))
  (db/insert :pending-upload-item {
    :pending-upload-id pending-upload-id
    :public-id public-id
    :content-type content-type
    :variant variant
  }))

(defn create-original-upload [file]
  (def file-id (get file :id))
  (def public-id (short-id/new))
  (db/insert :original-upload {
    :public-id public-id
    :file-id file-id
    }))
