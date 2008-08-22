require "tokyocabinet"
module TokyoCabinet
  
  # This method is executed in the end of this file:
  #   override_constants! unless $DO_NOT_OVERRIDE_TOKYOCABINET
  def self.override_constants!
    remove_const(:BDB)
    remove_const(:HDB)
    const_set(:BDB, BDB2)
    const_set(:HDB, HDB2)
  end
  
  # Methods common for both HDB and BDB.
  module CommonExtensions
    
    def initialize(options = {})
      super()
      @cmpfunc = options.delete(:cmp)
      @tuneoptions = options
      @cacheopts = {}
      @cacheopts[:lcnum] = options.delete(:lcnum) # BDB-only
      @cacheopts[:ncnum] = options.delete(:ncnum) # BDB-only
      @cacheopts[:rcnum] = options.delete(:rcnum) # HDB-only
      @cacheopts = {} if @cacheopts.values.empty?
    end
    
    def open(options, *args)
      # Fall to standard API
      return (super(options, *args) or tc_raise) unless options.kind_of?(Hash)
      # Hooks before open
      tune(@tuneoptions) unless @tuneoptions.empty?
      setcache(@cacheopts) unless @cacheopts.empty?
      super(*yield) or tc_raise
    end
    
    def close
      super or tc_raise
    end

    def copy(path)
      super or tc_raise
    end
    
    def sync
      super or tc_raise
    end
    
    def vanish
      super or tc_raise
    end
    
    def tune(options, *args)
      return (super(options, *args) or tc_raise) unless options.kind_of?(Hash)
      super(*make_tune_options(options)) or tc_raise
    end
    
    def optimize(options, *args)
      return (super(options, *args) or tc_raise) unless options.kind_of?(Hash)
      super(*make_tune_options(options)) or tc_raise
    end
        
  private
  
    def make_tune_options(options)
      raise "Please define make_tune_options in a subclass!"
    end
    
    def tc_raise
      raise(TokyoCabinet::Error, "#{self.class} Error: %s\n" % errmsg(ecode))
    end
  end # CommonExtensions
  
  
  
  
  #
  #
  #
  class HDB2 < HDB
    include CommonExtensions
    
    # Set the custom comparison function. `cmp' specifies the custom comparison function. 
    # It should be an instance of the class `Proc'. 
    # If successful, the return value is true, else, it is false. 
    # The default comparison function compares keys of two records by lexical order. 
    # The constants `TokyoCabinet::BDB::CMPLEXICAL' (default), 
    #               `TokyoCabinet::BDB::CMPDECIMAL', 
    #               `TokyoCabinet::BDB::CMPINT32', and 
    #               `TokyoCabinet::BDB::CMPINT64' are built-in. 
    # Note that the comparison function should be set before the database is opened. 
    # Moreover, user-defined comparison functions should be set every time the database is being opened. 
    def setcmpfunc(cmp)
      cmp = BDB::CMPLEXICAL if cmp == :lexical
      cmp = BDB::CMPDECIMAL if cmp == :decimal
      cmp = BDB::CMPINT32   if cmp == :int32
      cmp = BDB::CMPINT64   if cmp == :int64
      super(cmp)
    end
    
    # Open a database file. 
    # `path' specifies the path of the database file. 
    # `omode' specifies the connection mode: 
    #   `TokyoCabinet::HDB::OWRITER' as a writer, 
    #   `TokyoCabinet::HDB::OREADER' as a reader. 
    #  If the mode is `TokyoCabinet::BDB::OWRITER', the following may be added by bitwise or: 
    #   `TokyoCabinet::HDB::OCREAT', which means it creates a new database if not exist, 
    #   `TokyoCabinet::HDB::OTRUNC', which means it creates a new database regardless if one exists. 
    #  Both of `TokyoCabinet::HDB::OREADER' and `TokyoCabinet::HDB::OWRITER' can be added to by bitwise or:
    #   `TokyoCabinet::HDB::ONOLCK', which means it opens the database file without file locking, or 
    #   `TokyoCabinet::HDB::OLCKNB', which means locking is performed without blocking. 
    #  If it is not defined, `TokyoCabinet::HDB::OREADER' is specified. 
    #  If successful, the return value is true, else, it is false.
    # 
    def open(options, *args)
      super(options, *args) do
        # Open options
        options = {:lock => true}.merge(options)
        path = options[:path]
        omode = (options[:writer] ? HDB::OWRITER : HDB::OREADER)
        omode |= HDB::OCREAT if options[:create]
        omode |= HDB::OTRUNC if options[:truncate]
        omode |= HDB::ONOLCK if options[:lock] == false
        omode |= HDB::OLCKNB if options[:lock] == :noblock
        [path, omode]
      end
    end
     
    #  Set the caching parameters.
    def setcache(options, *args)
      return (super(options, *args) or tc_raise) unless options.kind_of?(Hash)
      rcnum = options[:rcnum] || 0
      super(rcnum) or tc_raise
    end

    def iterinit
      super or tc_raise
    end
            
  private
    # `bnum'  specifies the number of elements of the bucket array. 
    #         If it is not more than 0, the default value is specified. 
    #         The default value is 16381. 
    #         Suggested size of the bucket array is about from 1 to 4 times of the number of all pages to be stored.
    # `apow'  specifies the size of record alignment by power of 2. 
    #         If it is negative, the default value is specified. 
    #         The default value is 8 standing for 2^8=256.
    # `fpow'  specifies the maximum number of elements of the free block pool by power of 2. 
    #         If it is negative, the default value is specified. 
    #         The default value is 10 standing for 2^10=1024.
    # `opts' specifies options by bitwise or: 
    #   `TokyoCabinet::BDB::TLARGE'   specifies that the size of the database can be larger than 2GB by using 64-bit bucket array,
    #   `TokyoCabinet::BDB::TDEFLATE' specifies that each record is compressed with Deflate encoding, 
    #   `TokyoCabinet::BDB::TBZIP'    specifies that each record is compressed with BZIP2 encoding, 
    #   `TokyoCabinet::BDB::TTCBS'    specifies that each record is compressed with TCBS encoding. 
    #   If it is not defined, no option is specified.
    DEFAULT_TUNE_OPTIONS = {:bnum => 0, :apow => -1, :fpow => -1, :opts => 0xff}
    def make_tune_options(options)
      options = DEFAULT_TUNE_OPTIONS.merge(options)
      opts = options[:opts] || 0
      opts |= HDB::TLARGE   if options[:large]
      opts |= HDB::TDEFLATE if options[:compress].to_s.downcase == "deflate"
      opts |= HDB::TBZIP    if options[:compress].to_s.downcase == "bzip"
      opts |= HDB::TTCBS    if options[:compress].to_s.downcase == "tcbs"
      options[:opts] = opts
      [:bnum, :apow, :fpow, :opts].map do |name|
        options[name]
      end
    end
  end # HDB2
  
  
  
  #
  #
  #
  class BDB2 < BDB
    include CommonExtensions
    
    # Set the custom comparison function. `cmp' specifies the custom comparison function. 
    # It should be an instance of the class `Proc'. 
    # If successful, the return value is true, else, it is false. 
    # The default comparison function compares keys of two records by lexical order. 
    # The constants `TokyoCabinet::BDB::CMPLEXICAL' (default), 
    #               `TokyoCabinet::BDB::CMPDECIMAL', 
    #               `TokyoCabinet::BDB::CMPINT32', and 
    #               `TokyoCabinet::BDB::CMPINT64' are built-in. 
    # Note that the comparison function should be set before the database is opened. 
    # Moreover, user-defined comparison functions should be set every time the database is being opened. 
    def setcmpfunc(cmp)
      cmp = BDB::CMPLEXICAL if cmp == :lexical
      cmp = BDB::CMPDECIMAL if cmp == :decimal
      cmp = BDB::CMPINT32   if cmp == :int32
      cmp = BDB::CMPINT64   if cmp == :int64
      super(cmp)
    end
    
    # Open a database file. 
    # `path' specifies the path of the database file. 
    # `omode' specifies the connection mode: 
    #   `TokyoCabinet::BDB::OWRITER' as a writer, 
    #   `TokyoCabinet::BDB::OREADER' as a reader. 
    #  If the mode is `TokyoCabinet::BDB::OWRITER', the following may be added by bitwise or: 
    #   `TokyoCabinet::BDB::OCREAT', which means it creates a new database if not exist, 
    #   `TokyoCabinet::BDB::OTRUNC', which means it creates a new database regardless if one exists. 
    #  Both of `TokyoCabinet::BDB::OREADER' and `TokyoCabinet::BDB::OWRITER' can be added to by bitwise or:
    #   `TokyoCabinet::BDB::ONOLCK', which means it opens the database file without file locking, or 
    #   `TokyoCabinet::BDB::OLCKNB', which means locking is performed without blocking. 
    #  If it is not defined, `TokyoCabinet::BDB::OREADER' is specified. 
    #  If successful, the return value is true, else, it is false.
    # 
    def open(options, *args)
      super(options, *args) do
        setcmpfunc(@cmpfunc) if @cmpfunc
        # Open options
        options = {:lock => true}.merge(options)
        path = options[:path]
        omode = (options[:writer] ? BDB::OWRITER : BDB::OREADER)
        omode |= BDB::OCREAT if options[:create]
        omode |= BDB::OTRUNC if options[:truncate]
        omode |= BDB::ONOLCK if options[:lock] == false
        omode |= BDB::OLCKNB if options[:lock] == :noblock
        [path, omode]
      end
    end
     
    #  Set the caching parameters. 
    # `lcnum' specifies the maximum number of leaf nodes to be cached. 
    #         If it is not defined or not more than 0, the default value is specified. 
    #         The default value is 1024. 
    # `ncnum' specifies the maximum number of non-leaf nodes to be cached. 
    #         If it is not defined or not more than 0, the default value is specified. 
    #         The default value is 512. 
    #  If successful, the return value is true, else, it is false. 
    #  Note that the tuning parameters of the database should be set before the database is opened.
    #
    def setcache(options, *args)
      return (super(options, *args) or tc_raise) unless options.kind_of?(Hash)
      lcnum = options[:lcnum] || 0
      ncnum = options[:ncnum] || 0
      super(lcnum, ncnum) or tc_raise
    end

    def tranbegin
      super or tc_raise
    end
    
    def tranabort
      super or tc_raise
    end
    
    def trancommit
      super or tc_raise
    end
        
  private
    # `lmemb' specifies the number of members in each leaf page.
    #         If it is not more than 0, the default value is specified. 
    #         The default value is 128.
    # `nmemb' specifies the number of members in each non-leaf page. 
    #         If it is not more than 0, the default value is specified. 
    #         The default value is 256.
    # `bnum'  specifies the number of elements of the bucket array. 
    #         If it is not more than 0, the default value is specified. 
    #         The default value is 16381. 
    #         Suggested size of the bucket array is about from 1 to 4 times of the number of all pages to be stored.
    # `apow'  specifies the size of record alignment by power of 2. 
    #         If it is negative, the default value is specified. 
    #         The default value is 8 standing for 2^8=256.
    # `fpow'  specifies the maximum number of elements of the free block pool by power of 2. 
    #         If it is negative, the default value is specified. 
    #         The default value is 10 standing for 2^10=1024.
    # `opts' specifies options by bitwise or: 
    #   `TokyoCabinet::BDB::TLARGE'   specifies that the size of the database can be larger than 2GB by using 64-bit bucket array,
    #   `TokyoCabinet::BDB::TDEFLATE' specifies that each record is compressed with Deflate encoding, 
    #   `TokyoCabinet::BDB::TBZIP'    specifies that each record is compressed with BZIP2 encoding, 
    #   `TokyoCabinet::BDB::TTCBS'    specifies that each record is compressed with TCBS encoding. 
    #   If it is not defined, no option is specified.  
    DEFAULT_TUNE_OPTIONS = {:lmemb => 0, :nmemb => 0, :bnum => 0, :apow => -1, :fpow => -1, :opts => 0xff}
    def make_tune_options(options)
      options = DEFAULT_TUNE_OPTIONS.merge(options)
      opts = options[:opts] || 0
      opts |= BDB::TLARGE   if options[:large]
      opts |= BDB::TDEFLATE if options[:compress].to_s.downcase == "deflate"
      opts |= BDB::TBZIP    if options[:compress].to_s.downcase == "bzip"
      opts |= BDB::TTCBS    if options[:compress].to_s.downcase == "tcbs"
      options[:opts] = opts
      [:lmemb, :nmemb, :bnum, :apow, :fpow, :opts].map do |name|
        options[name]
      end
    end
  end # BDB2
  
  class Error < StandardError; end
  
  override_constants! unless $DO_NOT_OVERRIDE_TOKYOCABINET
end
