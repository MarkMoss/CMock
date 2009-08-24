require File.expand_path(File.dirname(__FILE__)) + "/../test_helper"
require 'cmock_header_parser'

class CMockHeaderParserTest < Test::Unit::TestCase

  def setup
    create_mocks :config
    @test_name = 'test_file.h'
    @config.expect.attributes.returns(['__ramfunc', 'funky_attrib'])
    @config.expect.treat_as_void.returns(['MY_FUNKY_VOID'])
    @config.expect.treat_as.returns({ "BANJOS" => "INT", "TUBAS" => "HEX16"} )
    @config.expect.when_no_prototypes.returns(:error)
    
    @parser = CMockHeaderParser.new(@config)
  end

  def teardown
  end
  
  should "create and initialize variables to defaults appropriately" do
    assert_equal([], @parser.funcs)
    assert_equal(['const', '__ramfunc', 'funky_attrib'], @parser.c_attributes)
    assert_equal(['void','MY_FUNKY_VOID'], @parser.treat_as_void)
  end
  
  should "strip out line comments" do
    source = 
      " abcd;\n" +
      "// hello;\n" +
      "who // is you\n"
    
    expected =
    [
      "abcd",
      "who"
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end
  
  
  should "remove block comments" do
    source = 
      " no_comments;\n" +
      "// basic_line_comment;\n" +
      "/* basic_block_comment;*/\n" +
      "pre_block; /* start_of_block_comment;\n" +
      "// embedded_line_comment_in_block_comment; */\n" +
      "// /* commented_out_block_comment_line\n" +
      "shown_because_block_comment_invalid_from_line_comment;\n" +
      "// */\n" +
      "//* shorter_commented_out_block_comment_line; \n" +
      "shown_because_block_comment_invalid_from_shorter_line_comment;\n" +
      "/*/\n" +
      "not_shown_because_line_above_started_comment;\n" +
      "//*/\n" +
      "/* \n" +
      "not_shown_because_block_comment_started_this_time;\n" +
      "/*/\n" +
      "shown_because_line_above_ended_comment_this_time;\n" +
      "//*/\n"
    
    expected =
    [
      "no_comments",
      "pre_block",
      "shown_because_block_comment_invalid_from_line_comment",
      "shown_because_block_comment_invalid_from_shorter_line_comment",
      "shown_because_line_above_ended_comment_this_time"
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end
  
  
  should "remove preprocessor directives" do
    source = 
      "#when stuff_happens\n" +
      "#ifdef _TEST\n" +
      "#pragma stack_switch"
    
    expected = []
    
    assert_equal(expected, @parser.import_source(source))
  end
  
  
  should "smush lines together that contain continuation characters" do
    source = 
      "hoo hah \\\n" +
      "when \\ \n"
    
    expected =
    [
      "hoo hah when"
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end
  
  
  should "remove C macro definitions" do
    source = 
      "#define this is the first line\\\n" +
      "and the second\\\n" +
      "and the third that should be removed\n" +
      "but I'm here\n"
    
    expected = ["but I'm here"]
    
    assert_equal(expected, @parser.import_source(source))
  end
  
  
  should "remove typedef statements" do
    source = 
      "typedef uint32 (unsigned int);\n" +
      "whack me? typedef int INT;\n" +
      "typedef who cares what really comes here \\\n" + # exercise multiline typedef
      "   continuation;\n" +
      "this should remain!"
    
    expected =
    [
      "whack me? this should remain!"
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end


  should "remove enum statements" do
    source = 
      "enum _NamedEnum {\n" +
      " THING1 = (0x0001),\n" +
      " THING2 = (0x0001 << 5),\n" +
      "}ListOValues;\n\n" +
      "don't delete me!!\n" +
      " modifier_str enum _NamedEnum {THING1 = (0x0001), THING2 = (0x0001 << 5)} ListOValues;\n\n" +
      "typedef enum {\n" +
      " THING1,\n" +
      " THING2,\n" +
      "} Thinger;\n" +
      "or me!!\n"
    
    assert_equal(["don't delete me!! or me!!"], @parser.import_source(source).map!{|s|s.strip})
  end


  should "remove union statements" do
    source = 
      "union _NamedDoohicky {\n" +
      " unsigned int a;\n" +
      " char b;\n" +
      "} Doohicky;\n\n" +
      "I want to live!!\n" +
      "some_modifier union { unsigned int a; char b;} Whatever;\n" +
      "typedef union {\n" +
      " unsigned int a;\n" +
      " char b;\n" +
      "} Whatever;\n" +
      "me too!!\n"
    
    assert_equal(["I want to live!! me too!!"], @parser.import_source(source).map!{|s|s.strip})
  end


  should "remove struct statements" do
    source = 
      "struct _NamedStruct1 {\n" +
      " unsigned int a;\n" +
      " signed long int b;\n" +
      "} Thing ;\n\n" +
      "extern struct ForwardDeclared_t TestDataType1;\n" +
      "void foo(void);\n" +
      "struct\n"+
      "   MultilineForwardDeclared_t\n" +
      "   TestDataType2;\n" +
      "struct THINGER foo(void);\n" +
      "typedef struct {\n" +
      " unsigned int a;\n" +
      " signed char b;\n" +
      "}Thinger;\n" +
      "I want to live!!\n"

    assert_equal(["void foo(void)", "struct THINGER foo(void)", "I want to live!!"], 
                 @parser.import_source(source).map!{|s|s.strip})
  end
  
  
  should "remove externed and inline functions" do
    source = 
      " extern uint32 foobar(unsigned int);\n" +
      "uint32 extern_name_func(unsigned int);\n" +
      "uint32 funcinline(unsigned int);\n" +
      "extern void bar(unsigned int);\n" +
      "inline void bar(unsigned int);\n" +
      "extern\n" +
      "void kinda_ugly_on_the_next_line(unsigned int);\n"
    
    expected =
    [
      "uint32 extern_name_func(unsigned int)",
      "uint32 funcinline(unsigned int)"
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end
    
  
  should "remove defines" do
    source =
      "#define whatever you feel like defining\n" +
      "void hello(void);\n" +
      "#DEFINE I JUST DON'T CARE\n" +
      "#deFINE\n" +
      "#define get_foo() \\\n   ((Thing)foo.bar)" # exercise multiline define
    
    expected =
    [
      "void hello(void)",
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end
    
  
  should "remove keywords that would keep things from going smoothly in the future" do
    source =
      "const int TheMatrix(register int Trinity, unsigned int *restrict Neo)"
    
    expected =
    [
      "const int TheMatrix(int Trinity, unsigned int * Neo)",
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end


  # some code actually typedef's void even though it's not ANSI C and is, frankly, weird
  # since cmock treats void specially, we can't let void be obfuscated
  should "handle odd case of typedef'd void returned" do  
    source = "MY_FUNKY_VOID FunkyVoidReturned(int a)"
    expected = { :var_arg=>nil,
                 :return_string=>"void toReturn",
                 :name=>"FunkyVoidReturned",
                 :return_type=>"void",
                 :modifier=>"",
                 :args=>[{:type=>"int", :name=>"a"}],
                 :args_string=>"int a" }
    assert_equal(expected, @parser.parse_declaration(source))
  end
  
  should "handle odd case of typedef'd void as arg" do 
    source = "int FunkyVoidAsArg(MY_FUNKY_VOID)"
    expected = { :var_arg=>nil,
                 :return_string=>"int toReturn",
                 :name=>"FunkyVoidAsArg",
                 :return_type=>"int",
                 :modifier=>"",
                 :args=>[],
                 :args_string=>"void" }
    assert_equal(expected, @parser.parse_declaration(source))
  end
  
  should "handle odd case of typedef'd void as arg pointer" do 
    source = "char FunkyVoidPointer(MY_FUNKY_VOID* bluh)"
    expected = { :var_arg=>nil,
                 :return_string=>"char toReturn",
                 :name=>"FunkyVoidPointer",
                 :return_type=>"char",
                 :modifier=>"",
                 :args=>[{:type=>"MY_FUNKY_VOID*", :name=>"bluh"}],
                 :args_string=>"MY_FUNKY_VOID* bluh" }
    assert_equal(expected, @parser.parse_declaration(source))        
  end


  should "strip default values from function parameter lists" do  
    source =
      "void Foo(int a = 57, float b=37.52, char c= 'd', char* e=\"junk\");\n"

    expected =
    [
      "void Foo(int a, float b, char c, char* e)"
    ]
    
    assert_equal(expected, @parser.import_source(source).map!{|s|s.strip})
  end


  should "raise upon empty file" do  
    source = ''
        
    # ensure it's expected type of exception
    assert_raise RuntimeError do
      @parser.parse("")
    end

    assert_equal([], @parser.funcs)
    
    # verify exception message
    begin
      @parser.parse("")
    rescue RuntimeError => e
      assert_equal("ERROR: No function prototypes found!", e.message)
    end    
  end


  should "raise upon no function prototypes found in file" do  
    source = 
      "typedef void SILLY_VOID_TYPE1;\n" +
      "typedef (void) SILLY_VOID_TYPE2 ;\n" +
      "typedef ( void ) (*FUNCPTR)(void);\n\n" + 
      "#define get_foo() \\\n   ((Thing)foo.bar)"

    # ensure it's expected type of exception
    assert_raise(RuntimeError) do
      @parser.parse(source)
    end

    assert_equal([], @parser.funcs)    

    # verify exception message
    begin
      @parser.parse(source)    
    rescue RuntimeError => e
      assert_equal("ERROR: No function prototypes found!", e.message)
    end    
  end


  should "raise upon prototype parsing failure" do
    source = "void (int, )" 

    # ensure it's expected type of exception
    assert_raise(RuntimeError) do
      @parser.parse(source)
    end

    # verify exception message
    begin
      @parser.parse(source) 
    rescue RuntimeError => e
      assert(e.message.include? "Failed Parsing Declaration Prototype!")
    end    
  end

  should "extract and return function declarations with retval and args" do
  
    source = "int Foo(int a, unsigned int b)"
    expected = { :var_arg=>nil,
                 :return_string=>"int toReturn",
                 :name=>"Foo",
                 :return_type=>"int",
                 :modifier=>"",
                 :args=>[ {:type=>"int", :name=>"a"}, 
                          {:type=>"unsigned int", :name=>"b"}
                        ],
                 :args_string=>"int a, unsigned int b" }
    assert_equal(expected, @parser.parse_declaration(source))
  end

  should "extract and return function declarations with no retval" do
  
    source = "void    FunkyChicken(    uint la,  int     de, bool da)"
    expected = { :var_arg=>nil,
                 :return_string=>"void toReturn",
                 :name=>"FunkyChicken",
                 :return_type=>"void",
                 :modifier=>"",
                 :args=>[ {:type=>"uint", :name=>"la"}, 
                          {:type=>"int",  :name=>"de"},
                          {:type=>"bool", :name=>"da"}
                        ],
                 :args_string=>"uint la, int     de, bool da" }
    assert_equal(expected, @parser.parse_declaration(source))
  end

  should "extract and return function declarations with implied voids" do
  
    source = "void tat()"
    expected = { :var_arg=>nil,
                 :return_string=>"void toReturn",
                 :name=>"tat",
                 :return_type=>"void",
                 :modifier=>"",
                 :args=>[ ],
                 :args_string=>"void" }
    assert_equal(expected, @parser.parse_declaration(source))
  end
  
  should "extract modifiers properly" do
  
    source = "const int TheMatrix(int Trinity, unsigned int * Neo)"
    expected = { :var_arg=>nil,
                 :return_string=>"int toReturn",
                 :name=>"TheMatrix",
                 :return_type=>"int",
                 :modifier=>"const",
                 :args=>[ {:type=>"int",           :name=>"Trinity"}, 
                          {:type=>"unsigned int*", :name=>"Neo"}
                        ],
                 :args_string=>"int Trinity, unsigned int* Neo" }
    assert_equal(expected, @parser.parse_declaration(source))
  end
  
  should "should fully parse multiple prototypes" do
  
    source = "const int TheMatrix(int Trinity, unsigned int * Neo);\n" + 
             "int Morpheus(int, unsigned int*);\n"
             
    expected = [{ :var_arg=>nil,
                  :return_string=>"int toReturn",
                  :name=>"TheMatrix",
                  :return_type=>"int",
                  :modifier=>"const",
                  :args=>[ {:type=>"int",           :name=>"Trinity"}, 
                           {:type=>"unsigned int*", :name=>"Neo"}
                         ],
                  :args_string=>"int Trinity, unsigned int* Neo" },
                { :var_arg=>nil,
                  :return_string=>"int toReturn",
                  :name=>"Morpheus",
                  :return_type=>"int",
                  :modifier=>"",
                  :args=>[ {:type=>"int",           :name=>"cmock_arg1"}, 
                           {:type=>"unsigned int*", :name=>"cmock_arg2"}
                         ],
                  :args_string=>"int cmock_arg1, unsigned int* cmock_arg2" 
                }]
    assert_equal(expected, @parser.parse(source)[:functions])
  end
  
  should "not extract for mocking multiply defined prototypes" do
  
    source = "const int TheMatrix(int Trinity, unsigned int * Neo);\n" + 
             "const int TheMatrix(int, unsigned int*);\n"
             
    expected = [{ :var_arg=>nil,
                  :return_string=>"int toReturn",
                  :name=>"TheMatrix",
                  :return_type=>"int",
                  :modifier=>"const",
                  :args=>[ {:type=>"int",           :name=>"Trinity"}, 
                           {:type=>"unsigned int*", :name=>"Neo"}
                         ],
                  :args_string=>"int Trinity, unsigned int* Neo" 
                }]
    assert_equal(expected, @parser.parse(source)[:functions])
  end
  
  should "properly detect typedef'd variants of void and use those" do
  
    source = "typedef (void) FUNKY_VOID_T;\n" + 
             "typedef void CHUNKY_VOID_T;\n" +
             "FUNKY_VOID_T DrHorrible(int SingAlong);\n" +
             "int CaptainHammer(CHUNKY_VOID_T);\n"
             
    expected = [{ :var_arg=>nil,
                  :return_string=>"void toReturn",
                  :name=>"DrHorrible",
                  :return_type=>"void",
                  :modifier=>"",
                  :args=>[ {:type=>"int", :name=>"SingAlong"} ],
                  :args_string=>"int SingAlong" 
                },
                { :var_arg=>nil,
                  :return_string=>"int toReturn",
                  :name=>"CaptainHammer",
                  :return_type=>"int",
                  :modifier=>"",
                  :args=>[ ],
                  :args_string=>"void" 
                }]
    assert_equal(expected, @parser.parse(source)[:functions])
  end
  
  should "be ok with structs inside of function declarations" do
  
    source = "int DrHorrible(struct SingAlong Blog);\n" +
             "void Penny(struct const _KeepYourHeadUp_ * const BillyBuddy);\n" +
             "struct TheseArentTheHammer CaptainHammer(void);\n"
             
    expected = [{ :var_arg=>nil,
                  :return_string=>"int toReturn",
                  :name=>"DrHorrible",
                  :return_type=>"int",
                  :modifier=>"",
                  :args=>[ {:type=>"struct SingAlong", :name=>"Blog"} ],
                  :args_string=>"struct SingAlong Blog" 
                },
                { :var_arg=>nil,
                  :return_string=>"void toReturn",
                  :name=>"Penny",
                  :return_type=>"void",
                  :modifier=>"",
                  :args=>[ {:type=>"struct _KeepYourHeadUp_*", :name=>"BillyBuddy"} ],
                  :args_string=>"struct const _KeepYourHeadUp_* const BillyBuddy" 
                },
                { :var_arg=>nil,
                  :return_string=>"struct TheseArentTheHammer toReturn",
                  :name=>"CaptainHammer",
                  :return_type=>"struct TheseArentTheHammer",
                  :modifier=>"",
                  :args=>[ ],
                  :args_string=>"void" 
                }]
    assert_equal(expected, @parser.parse(source)[:functions])
  end
  
  should "extract functions with varargs" do
  
    source = "int XFiles(int Scully, int Mulder, ...);\n"
    expected = [{ :var_arg=>"...",
                  :return_string=>"int toReturn",
                  :name=>"XFiles",
                  :return_type=>"int",
                  :modifier=>"",
                  :args=>[ {:type=>"int", :name=>"Scully"}, 
                           {:type=>"int", :name=>"Mulder"}
                         ],
                  :args_string=>"int Scully, int Mulder" 
               }]
    assert_equal(expected, @parser.parse(source)[:functions])
  end

end