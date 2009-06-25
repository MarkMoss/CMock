
class CMockGeneratorPluginExpect

  attr_accessor :config, :utils, :tab, :unity_helper, :ordered

  def initialize(config, utils)
    @config       = config
	  @tab          = @config.tab
    @ptr_handling = @config.when_ptr_star
    @ordered      = @config.enforce_strict_ordering
    @utils        = utils
    @unity_helper = @utils.helpers[:unity_helper]
  end
  
  def instance_structure(function)
    call_count_type = @config.expect_call_count_type
    lines = [ "#{@tab}#{call_count_type} #{function[:name]}_CallCount;\n",
              "#{@tab}#{call_count_type} #{function[:name]}_CallsExpected;\n" ]
      
    if (function[:return_type] != "void")
      lines << [ "#{@tab}#{function[:return_type]} *#{function[:name]}_Return;\n",
                 "#{@tab}#{function[:return_type]} *#{function[:name]}_Return_Head;\n",
                 "#{@tab}#{function[:return_type]} *#{function[:name]}_Return_Tail;\n" ]
    end

    if (@ordered)
      lines << [ "#{@tab}int *#{function[:name]}_CallOrder;\n",
                 "#{@tab}int *#{function[:name]}_CallOrder_Head;\n",
                 "#{@tab}int *#{function[:name]}_CallOrder_Tail;\n" ]
    end
    
    function[:args].each do |arg|
      lines << [ "#{@tab}#{arg[:type]} *#{function[:name]}_Expected_#{arg[:name]};\n",
                 "#{@tab}#{arg[:type]} *#{function[:name]}_Expected_#{arg[:name]}_Head;\n",
                 "#{@tab}#{arg[:type]} *#{function[:name]}_Expected_#{arg[:name]}_Tail;\n" ]
    end
    lines.flatten
  end
  
  def mock_function_declarations(function)
    if (function[:args_string] == "void")
      if (function[:return_type] == 'void')
        return ["void #{function[:name]}_Expect(void);\n"]
      else
        return ["void #{function[:name]}_ExpectAndReturn(#{function[:return_string]});\n"]
      end
    else        
      if (function[:return_type] == 'void')
        return ["void #{function[:name]}_Expect(#{function[:args_string]});\n"]
      else
        return ["void #{function[:name]}_ExpectAndReturn(#{function[:args_string]}, #{function[:return_string]});\n"]
      end
    end
  end
  
  def mock_implementation(function)
    lines = [ "#{@tab}Mock.#{function[:name]}_CallCount++;\n",
              "#{@tab}if (Mock.#{function[:name]}_CallCount > Mock.#{function[:name]}_CallsExpected)\n",
              "#{@tab}{\n",
              "#{@tab}#{@tab}TEST_FAIL(\"Function '#{function[:name]}' called more times than expected\");\n",
              "#{@tab}}\n" ]
    
    if (@ordered)
      err_msg = "Out of order function calls. Function '#{function[:name]}'" #" expected to be call %i but was call %i"
      lines << [ "#{@tab}{\n",
                 "#{@tab}#{@tab}int* p_expected = Mock.#{function[:name]}_CallOrder;\n",
                 "#{@tab}#{@tab}++GlobalVerifyOrder;\n",
                 "#{@tab}#{@tab}if (Mock.#{function[:name]}_CallOrder != Mock.#{function[:name]}_CallOrder_Tail)\n",
                 "#{@tab}#{@tab}#{@tab}Mock.#{function[:name]}_CallOrder++;\n",
                 "#{@tab}#{@tab}if ((*p_expected != GlobalVerifyOrder) && (GlobalOrderError == NULL))\n",
                 "#{@tab}#{@tab}{\n",
                 "#{@tab}#{@tab}#{@tab}const char* ErrStr = \"#{err_msg}\";\n",
                 "#{@tab}#{@tab}#{@tab}GlobalOrderError = malloc(#{err_msg.size + 1});\n",
                 "#{@tab}#{@tab}#{@tab}if (GlobalOrderError)\n",
                 "#{@tab}#{@tab}#{@tab}#{@tab}strcpy(GlobalOrderError, ErrStr);\n",
                 "#{@tab}#{@tab}}\n",
                 "#{@tab}}\n" ]
    end
    
    function[:args].each do |arg|
      lines << @utils.code_verify_an_arg_expectation(function, arg[:type], arg[:name])
    end
    lines.flatten
  end
  
  def mock_interfaces(function)
    lines = []
    
    # Parameter Helper Function
    if (function[:args_string] != "void")
      lines << "void ExpectParameters_#{function[:name]}(#{function[:args_string]})\n"
      lines << "{\n"
      function[:args].each do |arg|
        lines << @utils.code_add_an_arg_expectation(function, arg[:type], arg[:name])
      end
      lines << "}\n\n"
    end
    
    #Main Mock Interface
    if (function[:return_type] == "void")
      lines << "void #{function[:name]}_Expect(#{function[:args_string]})\n"
    else
      if (function[:args_string] == "void")
        lines << "void #{function[:name]}_ExpectAndReturn(#{function[:return_string]})\n"
      else
        lines << "void #{function[:name]}_ExpectAndReturn(#{function[:args_string]}, #{function[:return_string]})\n"
      end
    end
    lines << "{\n"
    lines << @utils.code_add_base_expectation(function[:name])
    
    if (function[:args_string] != "void")
      lines << "#{@tab}ExpectParameters_#{function[:name]}(#{@utils.create_call_list(function)});\n"
    end
    
    if (function[:return_type] != "void")
      lines << @utils.code_insert_item_into_expect_array(function[:return_type], "Mock.#{function[:name]}_Return_Head", 'toReturn')
      lines << "#{@tab}Mock.#{function[:name]}_Return = Mock.#{function[:name]}_Return_Head;\n"
      lines << "#{@tab}Mock.#{function[:name]}_Return += Mock.#{function[:name]}_CallCount;\n"
    end
    lines << "}\n\n"
  end
  
  def mock_verify(function)
    ["#{@tab}TEST_ASSERT_EQUAL_MESSAGE(Mock.#{function[:name]}_CallsExpected, Mock.#{function[:name]}_CallCount, \"Function '#{function[:name]}' called unexpected number of times.\");\n"]
  end
  
  def mock_destroy(function)
    lines = []
    if (function[:return_type] != "void")
      lines << [ "#{@tab}if (Mock.#{function[:name]}_Return_Head)\n",
                 "#{@tab}{\n",
                 "#{@tab}#{@tab}free(Mock.#{function[:name]}_Return_Head);\n",
                 "#{@tab}}\n",
                 "#{@tab}Mock.#{function[:name]}_Return=NULL;\n",
                 "#{@tab}Mock.#{function[:name]}_Return_Head=NULL;\n",
                 "#{@tab}Mock.#{function[:name]}_Return_Tail=NULL;\n"
               ]
    end
    if (@ordered)
      lines << [ "#{@tab}if (Mock.#{function[:name]}_CallOrder_Head)\n",
                 "#{@tab}{\n",
                 "#{@tab}#{@tab}free(Mock.#{function[:name]}_CallOrder_Head);\n",
                 "#{@tab}}\n",
                 "#{@tab}Mock.#{function[:name]}_CallOrder=NULL;\n",
                 "#{@tab}Mock.#{function[:name]}_CallOrder_Head=NULL;\n",
                 "#{@tab}Mock.#{function[:name]}_CallOrder_Tail=NULL;\n"
                ]
    end
    function[:args].each do |arg|
      lines << [ "#{@tab}if (Mock.#{function[:name]}_Expected_#{arg[:name]}_Head)\n",
                 "#{@tab}{\n",
                 "#{@tab}#{@tab}free(Mock.#{function[:name]}_Expected_#{arg[:name]}_Head);\n",
                 "#{@tab}}\n",
                 "#{@tab}Mock.#{function[:name]}_Expected_#{arg[:name]}=NULL;\n",
                 "#{@tab}Mock.#{function[:name]}_Expected_#{arg[:name]}_Head=NULL;\n",
                 "#{@tab}Mock.#{function[:name]}_Expected_#{arg[:name]}_Tail=NULL;\n"
               ]
    end
    lines.flatten
  end
end
