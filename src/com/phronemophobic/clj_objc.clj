(ns com.phronemophobic.clj-objc
  (:require [tech.v3.datatype.ffi :as dt-ffi]
            [tech.v3.datatype :as dtype]
            tech.v3.datatype.ffi.graalvm-runtime
            [tech.v3.datatype.native-buffer :as native-buffer]
            [tech.v3.datatype.ffi.size-t :as ffi-size-t]
            [tech.v3.datatype.casting :as casting])
  (:import [tech.v3.datatype.native_buffer NativeBuffer]
           [tech.v3.datatype.ffi Pointer])
  (:gen-class))

(defn long->pointer [n]
  (Pointer. n))

(set! *warn-on-reflection* true)
;; https://developer.apple.com/documentation/objectivec/objective-c_runtime?language=objc
;; https://developer.apple.com/tutorials/data/documentation/objectivec/objective-c_runtime.json?language=objc

;; blocks
;; https://www.galloway.me.uk/2012/10/a-look-inside-blocks-episode-1/

;; id objc_getClass(const char *name);

;; id class_createInstance(Class cls, size_t extraBytes);
;; Class NSClassFromString(NSString *aClassName);


;; more blocks
;; is the signature?
;; https://developer.apple.com/documentation/foundation/nsmethodsignature

;; I think the plan is to create an nsblock
;; set the c function pointer with extra arg
;; profit?

(def objclib-fns
  {

   :run_on_main {:rettype :void
                 :argtypes [['block :pointer]]}

   :call_objc {:rettype :void
               :argtypes [['rettype :int32]
                          ['ret :pointer?]
                          ['nargs :int32]
                          ['argtypes :pointer]
                          ['args :pointer]]}

   :print_objc {:rettype :void
                :argtypes [['obj :pointer]]}

   :objc_getClass {:rettype :pointer
                   :argtypes [['class-name :pointer]]}

   :sel_registerName {:rettype :pointer
                      :argtypes [['sel-name :pointer]]}

   :make_block {:rettype :pointer
                :argtypes [['callback-id :pointer]
                           ['rettype :int32]
                           ['nargs :int32]
                           ['argtypes :pointer?]]}

   ,})

(defonce ^:private lib (dt-ffi/library-singleton #'objclib-fns))
(defn set-library-instance!
  [lib-instance]
  (dt-ffi/library-singleton-set-instance! lib lib-instance))

(dt-ffi/library-singleton-reset! lib)

(defn- find-fn
  [fn-kwd]
  (dt-ffi/library-singleton-find-fn lib fn-kwd))

(defmacro check-error
  [fn-def & body]
  `(let [error-val# (long (do ~@body))]
     (errors/when-not-errorf
      (>= error-val# 0)
      "Exception calling: (%d) - \"%s\""
      error-val# (if-let [err-name#  (get av-error/value->error-map error-val#)]
                   err-name#
                   (str-error error-val#)))
     error-val#))


(dt-ffi/define-library-functions com.phronemophobic.clj-objc/objclib-fns find-fn check-error)

(defmacro if-class
  ([class-name then]
   `(if-class ~class-name
      ~then
      nil))
  ([class-name then else?]
   (let [class-exists (try
                        (Class/forName (name class-name))
                        true
                        (catch ClassNotFoundException e
                          false))]
     (if class-exists
       then
       else?))))

(def initialized?* (atom false))

(defn compile-bindings [& args]
  ((requiring-resolve 'tech.v3.datatype.ffi.graalvm/define-library)
   objclib-fns
   nil
   {
    ;;:header-files []
    :libraries [ ;;"@rpath/libcljbridge.so"
                ]
    :classname 'com.phronemohobic.clj-objc.Bindings})
  )

(when *compile-files*
  (compile-bindings))

(defn initialize-objc
  []
  (if-class com.phronemohobic.clj-objc.Bindings
    (if (first (swap-vals!
                initialized?*
                (fn [init]
                  (when-not init
                    (set-library-instance! (com.phronemohobic.clj-objc.Bindings.))
                    true))))
      1
      0)))


(defn string->sel [s]
  (sel_registerName (dt-ffi/string->c s)))

(defn string->class [s]
  (objc_getClass (dt-ffi/string->c s)))

(defn make-ptr-uninitialized
  "Make an object convertible to a pointer that points to  single value of type
  `dtype`."
  (^NativeBuffer [dtype options]
   (let [dtype (ffi-size-t/lower-ptr-type dtype)
         ^NativeBuffer nbuf (-> (native-buffer/malloc
                                 (casting/numeric-byte-width dtype)
                                 options)
                                (native-buffer/set-native-datatype dtype))]
     nbuf))
  (^NativeBuffer [dtype]
   (make-ptr-uninitialized dtype {:resource-type :auto
                                  :uninitialized? true})))




(defn argtype->int [kw]
  ;; values chosen arbitrarily
  ;; must match clj_objc.mm
  (case kw
    :void 0                ;; ffi_type_void
    (:pointer? :pointer) 1 ;; ffi_type_pointer
    :int8 2 ;; ffi_type_sint8
    :int16 3               ;; ffi_type_sint16
    :int32 4               ;; ffi_type_sint32
    :int64 5               ;; ffi_type_sint64
    :float32 6               ;; ffi_type_float
    :float64 7              ;; ffi_type_double
    ))


(defn call-objc [instance sel-name ret-type & types-and-args]
  (assert (even? (count types-and-args)))
  (let [instance (dt-ffi/->pointer instance)
        sel (dt-ffi/->pointer
             (string->sel sel-name))
        
        ret-ptr (if (= ret-type :void)
                  (long->pointer 0)
                  (make-ptr-uninitialized (if (= ret-type :pointer)
                                            :int64
                                            ret-type)))

        arg-types (take-nth 2 types-and-args)
        args (->>  types-and-args
                   (drop 1)
                   (take-nth 2))

        nargs (+ 2 (count args))

        rettype-int (argtype->int ret-type)
        argtype-ints (dtype/make-container :native-heap
                                           :int32
                                           (mapv argtype->int
                                                 (concat
                                                  [:pointer :pointer]
                                                  arg-types)))
        value-ptrs (mapv (fn [argtype arg]
                           (dt-ffi/make-ptr (if (= argtype :pointer)
                                              :int64
                                              argtype)
                                            (if (= argtype :pointer)
                                              (.address ^Pointer
                                                        (dt-ffi/->pointer arg))
                                              arg)))
                         (concat [:pointer :pointer]
                                 arg-types)
                         (concat [instance
                                  sel]
                                 args))
        values (dtype/make-container :native-heap
                                     :int64
                                     (mapv #(.address ^tech.v3.datatype.native_buffer.NativeBuffer %)
                                           value-ptrs))]
    
    ;; (prn (list 'call_objc rettype-int ret-ptr nargs argtype-ints values))
    (call_objc rettype-int ret-ptr nargs argtype-ints values)
    ;; no garbage collect
    (identity [values value-ptrs])
    
    (when (not= ret-type :void)
      (if (= ret-type :pointer)
        (long->pointer (nth ret-ptr 0))
        (nth ret-ptr 0)))))

(defn ->nsstring [s]
  (let [NSString (string->class "NSString")]
    (call-objc NSString
               "stringWithUTF8String:"
               :pointer
               :pointer (dt-ffi/string->c s))))

(defn ffi_test []
  (initialize-objc)
  (let [
        NSNumber (string->class "NSNumber")
        _ (print_objc NSNumber)        
        num (call-objc NSNumber
                       "numberWithFloat:"
                       :pointer
                       :float32 42.42)
        _ (prn "made num")
        _ (print_objc num)

        _ (prn "as char: "
               (call-objc num
                          "charValue"
                          :int8))


        woohoo (->nsstring "woohoo")
        _ (prn "made woohoo")
        _ (print_objc woohoo)

        NSMutableSet (string->class "NSMutableSet")
        my-set (call-objc NSMutableSet
                          "alloc"
                          :pointer)
        _ (prn "made set")

        my-set (call-objc my-set
                          "init"
                          :pointer)
        _ (prn "init set")
        _ (print_objc my-set)

        size (call-objc my-set
                        "count"
                        :int32)

        _ (call-objc my-set
                     "addObject:"
                     :void
                     :pointer woohoo)
        _ (call-objc my-set
                     "addObject:"
                     :void
                     :pointer (->nsstring "asdf"))
        _ (print_objc my-set)        

        size (call-objc my-set
                        "count"
                        :int32)
        _ (prn "size is now:" size)
        ]
    (prn "size is: " size)
    
    )
  #_(call-objc :obj "asdf"
             :int32 2
             :pointer 0)
  )


(defn read-args [arg-types arg-ptr]
  (let [unsafe (native-buffer/unsafe)
        args (map-indexed (fn [i arg-type]
                            (let [addr (+ (.address ^Pointer arg-ptr)
                                          (* 8 i))]
                              (case arg-type
                                :int8 (.getByte unsafe addr)
                                :int16 (.getShort unsafe addr)
                                :int32 (.getInt unsafe addr)
                                :int64 (.getLong unsafe addr)
                                :float32 (.getFloat unsafe addr)
                                :float64 (.getDouble unsafe addr)

                                (:pointer? :pointer) (long->pointer (.getLong unsafe addr)))))
                          arg-types)]
    args))



(defonce callbacks (atom [1 {}]))
(defn clj_callback [callback-id-ptr ret-ptr args-ptr]
  (let [unsafe (native-buffer/unsafe)
        callback-id (.getInt unsafe (.address ^Pointer callback-id-ptr))
        callback-info (-> @callbacks
                          second
                          (get callback-id))
        {:keys [f ret-type arg-types]} callback-info
        args (read-args arg-types args-ptr)
        ret-val (apply f args)

        ]
    
    (when (not= ret-type :void)
      (let [addr (.address ^Pointer ret-ptr)]
        (case ret-type
          :int8 (.putByte unsafe addr (unchecked-byte ret-val))
          :int16 (.putShort unsafe addr (unchecked-short ret-val))
          :int32 (.putInt unsafe addr (unchecked-int ret-val))
          :int64 (.putLong unsafe addr (unchecked-long ret-val))
          :float32 (.putFloat unsafe addr (unchecked-float ret-val))
          :float64 (.putDouble unsafe addr (unchecked-double ret-val))
          (:pointer :pointer?) (.putLong unsafe addr (.address ^Pointer ret-val)))))))



(defn make-block [f ret-type & arg-types]
  (let [callback-ptr (make-ptr-uninitialized :int32)
        callback-info {:f f
                       :ret-type ret-type
                       :arg-types arg-types
                       :callback-ptr callback-ptr}
        [callback-id _] (swap! callbacks
                               (fn [[last-callback-id m]]
                                 (let [next-callback-id (inc last-callback-id)
                                       m (assoc m next-callback-id callback-info)]
                                   [next-callback-id m])))

        _ (.putInt (native-buffer/unsafe)
                   (.address callback-ptr)
                   (unchecked-int callback-id))

        rettype-int (argtype->int ret-type)
        argtype-ints (dtype/make-container :native-heap
                                           :int32
                                           (mapv argtype->int
                                                 arg-types))
        nargs (count arg-types)

        block (make_block callback-ptr
                          rettype-int nargs argtype-ints)]
    block))




(defn make_test_block []
  (initialize-objc)
  (make-block (fn [a b]
                (println "make call")
                0)
              :int32
              :pointer :pointer))

(defonce callbacks (atom ()))
(defn dispatch-main [f]
  (let [block (make-block f :void)]
    (swap! callbacks conj f block)
    (run_on_main block)))

(defn compile-interface-class [& args]
  ((requiring-resolve 'tech.v3.datatype.ffi.graalvm/expose-clojure-functions)
   {
    #'ffi_test {:rettype :void}
    #'make_test_block {:rettype :int64}
    #'clj_callback {:rettype :void
                    :argtypes [['callback-id :pointer]
                               ['ret-ptr :pointer]
                               ['args-ptr :pointer]]}
    }
   'com.phronemophobic.clj_objc.interface nil))

(when *compile-files*
  (compile-interface-class))

(comment
  
  (->> (map ns-name (all-ns))
       (remove #(clojure.string/starts-with? % "clojure"))
       (map #(clojure.string/split (str %) #"\."))
       (keep butlast)
       (map #(clojure.string/join "." %))
       distinct
       (map munge)
       sort
       (cons "clojure"))
  ,)



(defn -main [& args])
