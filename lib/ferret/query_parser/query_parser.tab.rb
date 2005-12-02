#
# DO NOT MODIFY!!!!
# This file is automatically generated by racc 1.4.4
# from racc grammer file "lib/ferret/query_parser/query_parser.y".
#

require 'racc/parser'


module Ferret

  class QueryParser < Racc::Parser

module_eval <<'..end lib/ferret/query_parser/query_parser.y modeval..id6e7f6ac20b', 'lib/ferret/query_parser/query_parser.y', 126
  attr_accessor :default_field, :fields, :handle_parse_errors

  def initialize(default_field = "*", options = {})
    @yydebug = true
    if default_field.is_a?(String) and default_field.index("|")
      default_field = default_field.split("|")
    end
    @field = @default_field = default_field
    @analyzer = options[:analyzer] || Analysis::Analyzer.new
    @wild_lower = options[:wild_lower].nil? ? true : options[:wild_lower]
    @occur_default = options[:occur_default] || BooleanClause::Occur::SHOULD
    @default_slop = options[:default_slop] || 0
    @fields = options[:fields]||[]
    @handle_parse_errors = options[:handle_parse_errors] || false
  end

  RESERVED = {
    'AND'    => :AND,
    '&&'     => :AND,
    'OR'     => :OR,
    '||'     => :OR,
    'NOT'    => :NOT,
    '!'      => :NOT,
    '-'      => :NOT,
    'REQ'    => :REQ,
    '+'      => :REQ
  }

  ECHR =  %q,:()\[\]{}!+"~^\-\|<>\=\*\?,
  EWCHR = %q,:()\[\]{}!+"~^\-\|<>\=,

  def parse(str)
    orig_str = str
    str = clean_string(str)
    str.strip!
    @q = []

    until str.empty? do
      case str
      when /\A\s+/
        ;
      when /\A([#{EWCHR}]|[*?](?=:))/
        @q.push [ RESERVED[$&]||$&, $& ]
      when /\A(\&\&|\|\|)/
        @q.push [ RESERVED[$&], $& ]
      when /\A(\\[#{ECHR}]|[^\s#{ECHR}])*[?*](\\[#{EWCHR}]|[^\s#{EWCHR}])*/
        str = $'
        unescaped = $&.gsub(/\\(?!\\)/,"")
        @q.push [ :WILD_STRING, unescaped ]
        next
      when /\A(\\[#{ECHR}]|[^\s#{ECHR}])+/
        symbol = RESERVED[$&]
        if symbol
          @q.push [ symbol, $& ]
        else
          str = $'
          unescaped = $&.gsub(/\\(?!\\)/,"")
          @q.push [ :WORD, unescaped ]
          next
        end
      else
        raise RuntimeError, "shouldn't happen"
      end
      str = $'
    end
    if @q.empty?
      return TermQuery.new(Term.new(@default_field, ""))
    end

    @q.push([ false, '$' ])

    query = nil
    begin
      query = do_parse
    rescue Racc::ParseError => e
      if @handle_parse_errors
        @field = @default_field
        query = _get_bad_query(orig_str)
      else
        raise QueryParseException.new("Could not parse #{str}", e)
      end
    end
    return query
  end

  def next_token
    @q.shift
  end

  PHRASE_CHARS = [?<, ?>, ?|, ?"] # these chars have meaning within phrases
  def clean_string(str)
    escape_chars = ECHR.gsub(/\\/,"").unpack("c*")
    pb = nil
    br_stack = []
    quote_open = false
    # leave a little extra
    new_str = []

    str.each_byte do |b|
      # ignore escaped characters
      if pb == ?\\
        if quote_open and PHRASE_CHARS.index(b)
          new_str << ?\\ # this was left off the first time through
        end

        new_str << b
        pb = (b == ?\\ ? ?: : b) # \\ has escaped itself so does nothing more
        next
      end
      case b
      when ?\\
        new_str << b if !quote_open # We do our own escaping below
      when ?"
        quote_open = !quote_open
        new_str << b
      when ?(
        if !quote_open
          br_stack << b
        else
          new_str << ?\\
        end
        new_str << b
      when ?)
        if !quote_open
          if br_stack.size == 0
            new_str.unshift(?()
          else
            br_stack.pop
          end
        else
          new_str << ?\\
        end
        new_str << b
      when ?>
        if quote_open
          if pb == ?<
            new_str.delete_at(-2)
          else
            new_str << ?\\
          end
        end
        new_str << b
      else
        if quote_open
          if escape_chars.index(b) and b != ?|
            new_str << ?\\
          end
        end
        new_str << b
      end
      pb = b
    end
    new_str << ?" if quote_open
    br_stack.each { |b| new_str << ?) }
    return new_str.pack("c*")  
  end

  def get_bad_query(field, str)
    tokens = []
    stream = @analyzer.token_stream(field, str)
    while token = stream.next
      tokens << token
    end
    if tokens.length == 0
      return TermQuery.new(Term.new(field, ""))
    elsif tokens.length == 1
      return TermQuery.new(Term.new(field, tokens[0].term_text))
    else
      bq = BooleanQuery.new()
      tokens.each do |token|
        bq << BooleanClause.new(TermQuery.new(Term.new(field, token.term_text)))
      end
      return bq
    end
  end

  def get_range_query(field, start_word, end_word, inc_upper, inc_lower)
     RangeQuery.new(field, start_word, end_word, inc_upper, inc_lower)
  end

  def get_term_query(field, word)
    tokens = []
    stream = @analyzer.token_stream(field, word)
    while token = stream.next
      tokens << token
    end
    if tokens.length == 0
      return TermQuery.new(Term.new(field, ""))
    elsif tokens.length == 1
      return TermQuery.new(Term.new(field, tokens[0].term_text))
    else
      pq = PhraseQuery.new()
      tokens.each do |token|
        pq.add(Term.new(field, token.term_text), nil, token.position_increment)
      end
      return pq
    end
  end

  def get_fuzzy_query(field, word, min_sim = nil)
    tokens = []
    stream = @analyzer.token_stream(field, word)
    if token = stream.next # only makes sense to look at one term for fuzzy
      if min_sim
        return FuzzyQuery.new(Term.new(field, token.term_text), min_sim.to_f)
      else
        return FuzzyQuery.new(Term.new(field, token.term_text))
      end
    else
      return TermQuery.new(Term.new(field, ""))
    end
  end

  def get_wild_query(field, regexp)
    WildcardQuery.new(Term.new(field, regexp))
  end

  def add_multi_word(words, word)
    last_word = words[-1]
    if not last_word.is_a?(Array)
      last_word = words[-1] = [words[-1]]
    end
    last_word << word
    return words
  end

  def get_normal_phrase_query(field, positions)
    pq = PhraseQuery.new()
    pq.slop = @default_slop
    pos_inc = 0

    positions.each do |position|
      if position.nil?
        pos_inc += 1
        next
      end
      stream = @analyzer.token_stream(field, position)
      tokens = []
      while token = stream.next
        tokens << token
      end
      tokens.each do |token|
        pq.add(Term.new(field, token.term_text), nil,
               token.position_increment + pos_inc)
        pos_inc = 0
      end
    end
    return pq
  end

  def get_multi_phrase_query(field, positions)
    mpq = MultiPhraseQuery.new()
    mpq.slop = @default_slop
    pos_inc = 0

    positions.each do |position|
      if position.nil?
        pos_inc += 1
        next
      end
      if position.is_a?(Array)
        position.compact! # it doesn't make sense to have an empty spot here
        terms = []
        position.each do |word|
          stream = @analyzer.token_stream(field, word)
          if token = stream.next # only put one term per word
            terms << Term.new(field, token.term_text)
          end
        end
        mpq.add(terms, nil, pos_inc + 1) # must go at least one forward
        pos_inc = 0
      else
        stream = @analyzer.token_stream(field, position)
        tokens = []
        while token = stream.next
          tokens << token
        end
        tokens.each do |token|
          mpq.add([Term.new(field, token.term_text)], nil,
                 token.position_increment + pos_inc)
          pos_inc = 0
        end
      end
    end
    return mpq
  end

  def get_phrase_query(positions, slop = nil)
    if positions.size == 1 and not positions[0].is_a?(Array)
      return _get_term_query(positions[0])
    end

    multi_phrase = false
    positions.each do |position|
      if position.is_a?(Array)
        position.compact!
        if position.size > 1
          multi_phrase = true
        end
      end
    end

    return do_multiple_fields() do |field|
      q = nil
      if not multi_phrase
        q = get_normal_phrase_query(field, positions.flatten)
      else
        q = get_multi_phrase_query(field, positions)
      end
      q.slop = slop if slop
      next q
    end
  end

  def add_and_clause(clauses, clause)
    clauses.compact!
    if (clauses.length == 1)
      last_cl = clauses[0]
      last_cl.occur = BooleanClause::Occur::MUST if not last_cl.prohibited?
    end

    return if clause.nil? # incase a query got destroyed by the analyzer

    clause.occur = BooleanClause::Occur::MUST if not clause.prohibited?
    clauses << clause
  end

  def add_or_clause(clauses, clause)
    clauses << clause
  end

  def add_default_clause(clauses, clause)
    if @occur_default == BooleanClause::Occur::MUST
      add_and_clause(clauses, clause)
    else
      add_or_clause(clauses, clause)
    end
  end

  def get_boolean_query(clauses)
    # possible that we got all nil clauses so check
    return nil if clauses.nil?
    clauses.compact!
    return nil if clauses.size == 0

    if clauses.size == 1 and not clauses[0].prohibited?
      return clauses[0].query
    end
    bq = BooleanQuery.new()
    clauses.each {|clause| bq << clause }
    return bq                
  end                        
                             
  def get_boolean_clause(query, occur)
    return nil if query.nil?
    return BooleanClause.new(query, occur)
  end

  def do_multiple_fields()
    # set @field to all fields if @field is the multi-field operator
    @field = @fields if @field.is_a?(String) and @field == "*"
    if @field.is_a?(String)
      return yield(@field)
    elsif @field.size == 1
      return yield(@field[0])
    else
      bq = BooleanQuery.new()
      @field.each do |field|
        q = yield(field)
        bq << BooleanClause.new(q) if q
      end
      return bq                
    end
  end

  def method_missing(meth, *args)
    if meth.to_s =~ /_(get_[a-z_]+_query)/
      do_multiple_fields() do |field|
        send($1, *([field] + args))
      end
    else
      raise NoMethodError.new("No such method #{meth} in #{self.class}", meth, args)
    end
  end

  def QueryParser.parse(query, default_field = "*", options = {})
    qp = QueryParser.new(default_field, options)
    return qp.parse(query)
  end

..end lib/ferret/query_parser/query_parser.y modeval..id6e7f6ac20b

##### racc 1.4.4 generates ###

racc_reduce_table = [
 0, 0, :racc_error,
 1, 26, :_reduce_1,
 1, 27, :_reduce_2,
 3, 27, :_reduce_3,
 3, 27, :_reduce_4,
 2, 27, :_reduce_5,
 2, 28, :_reduce_6,
 2, 28, :_reduce_7,
 1, 28, :_reduce_8,
 1, 30, :_reduce_none,
 3, 30, :_reduce_10,
 1, 29, :_reduce_none,
 3, 29, :_reduce_12,
 1, 29, :_reduce_none,
 1, 29, :_reduce_none,
 1, 29, :_reduce_none,
 1, 29, :_reduce_none,
 1, 31, :_reduce_17,
 3, 31, :_reduce_18,
 2, 31, :_reduce_19,
 1, 35, :_reduce_20,
 0, 37, :_reduce_21,
 4, 32, :_reduce_22,
 0, 38, :_reduce_23,
 0, 39, :_reduce_24,
 5, 32, :_reduce_25,
 1, 36, :_reduce_26,
 3, 36, :_reduce_27,
 3, 33, :_reduce_28,
 5, 33, :_reduce_29,
 2, 33, :_reduce_30,
 4, 33, :_reduce_31,
 1, 40, :_reduce_32,
 2, 40, :_reduce_33,
 3, 40, :_reduce_34,
 3, 40, :_reduce_35,
 4, 34, :_reduce_36,
 4, 34, :_reduce_37,
 4, 34, :_reduce_38,
 4, 34, :_reduce_39,
 3, 34, :_reduce_40,
 3, 34, :_reduce_41,
 3, 34, :_reduce_42,
 3, 34, :_reduce_43,
 2, 34, :_reduce_44,
 3, 34, :_reduce_45,
 3, 34, :_reduce_46,
 2, 34, :_reduce_47 ]

racc_reduce_n = 48

racc_shift_n = 78

racc_action_table = [
     8,    10,    60,    59,    75,    74,    50,    21,     2,    25,
   -26,     7,     9,    41,    13,    15,    17,    19,     8,    10,
     3,    43,    64,    26,   -26,    21,     2,    40,    38,     7,
     9,    63,    13,    15,    17,    19,     8,    10,     3,    36,
    46,    53,    37,    21,     2,    49,    34,     7,     9,    45,
    13,    15,    17,    19,    58,    57,     3,     8,    10,    31,
    33,    54,    55,    56,    21,     2,    44,    48,     7,     9,
    61,    13,    15,    17,    19,    67,    66,     3,     8,    10,
    31,    33,    62,    42,    65,    21,     2,    39,    30,     7,
     9,    70,    13,    15,    17,    19,     8,    10,     3,    71,
    72,    73,    24,    21,     2,    77,   nil,     7,     9,   nil,
    13,    15,    17,    19,    21,     2,     3,   nil,     7,     9,
   nil,    13,    15,    17,    19,    21,     2,     3,   nil,     7,
     9,   nil,    13,    15,    17,    19,    21,     2,     3,   nil,
     7,     9,   nil,    13,    15,    17,    19,    21,     2,     3,
   nil,     7,     9,   nil,    13,    15,    17,    19,   nil,   nil,
     3 ]

racc_action_check = [
     0,     0,    38,    38,    64,    64,    30,     0,     0,     6,
    21,     0,     0,    17,     0,     0,     0,     0,     2,     2,
     0,    21,    42,     6,    21,     2,     2,    17,    15,     2,
     2,    42,     2,     2,     2,     2,    33,    33,     2,    13,
    24,    34,    15,    33,    33,    28,    13,    33,    33,    24,
    33,    33,    33,    33,    37,    35,    33,    23,    23,    23,
    23,    35,    35,    35,    23,    23,    23,    26,    23,    23,
    39,    23,    23,    23,    23,    46,    46,    23,    12,    12,
    12,    12,    40,    19,    43,    12,    12,    16,    11,    12,
    12,    53,    12,    12,    12,    12,    31,    31,    12,    54,
    55,    56,     3,    31,    31,    72,   nil,    31,    31,   nil,
    31,    31,    31,    31,    49,    49,    31,   nil,    49,    49,
   nil,    49,    49,    49,    49,    25,    25,    49,   nil,    25,
    25,   nil,    25,    25,    25,    25,     8,     8,    25,   nil,
     8,     8,   nil,     8,     8,     8,     8,    10,    10,     8,
   nil,    10,    10,   nil,    10,    10,    10,    10,   nil,   nil,
    10 ]

racc_action_pointer = [
    -3,   nil,    15,    92,   nil,   nil,     7,   nil,   126,   nil,
   137,    88,    75,    29,   nil,    18,    78,     3,   nil,    73,
   nil,     8,   nil,    54,    30,   115,    57,   nil,    43,   nil,
     6,    93,   nil,    33,    28,    45,   nil,    44,   -19,    60,
    72,   nil,    12,    74,   nil,   nil,    54,   nil,   nil,   104,
   nil,   nil,   nil,    81,    89,    87,    82,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   -17,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,    95,   nil,   nil,   nil,   nil,   nil ]

racc_action_default = [
   -48,   -14,   -48,   -48,   -15,   -16,   -48,   -20,   -48,   -23,
   -48,   -48,    -1,   -48,    -2,   -48,    -9,   -48,    -8,   -48,
   -11,   -17,   -13,   -48,   -48,   -48,   -48,    -6,   -48,    -7,
   -48,   -48,    -5,   -48,   -30,   -48,   -32,   -48,   -44,   -48,
   -48,   -47,   -48,   -19,   -12,   -43,   -48,   -21,   -27,   -48,
    78,    -3,    -4,   -48,   -48,   -28,   -48,   -33,   -45,   -40,
   -41,   -10,   -46,   -42,   -48,   -18,   -39,   -38,   -22,   -24,
   -31,   -35,   -48,   -34,   -37,   -36,   -25,   -29 ]

racc_goto_table = [
    27,    32,    29,    12,    68,    23,    11,    28,    76,    35,
   nil,   nil,    32,   nil,   nil,   nil,   nil,    47,   nil,   nil,
    51,   nil,    52,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,    69 ]

racc_goto_check = [
     4,     3,     4,     2,    12,     2,     1,    13,    14,    15,
   nil,   nil,     3,   nil,   nil,   nil,   nil,     4,   nil,   nil,
     3,   nil,     3,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,     4 ]

racc_goto_pointer = [
   nil,     6,     3,   -11,    -8,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   -43,    -2,   -61,    -4 ]

racc_goto_default = [
   nil,   nil,   nil,    14,    16,    18,    20,    22,     1,     4,
     5,     6,   nil,   nil,   nil,   nil ]

racc_token_table = {
 false => 0,
 Object.new => 1,
 ":" => 2,
 :REQ => 3,
 :NOT => 4,
 :AND => 5,
 :OR => 6,
 :HIGH => 7,
 :LOW => 8,
 "^" => 9,
 :WORD => 10,
 "(" => 11,
 ")" => 12,
 "~" => 13,
 :WILD_STRING => 14,
 "*" => 15,
 "|" => 16,
 "\"" => 17,
 "<" => 18,
 ">" => 19,
 "[" => 20,
 "]" => 21,
 "}" => 22,
 "{" => 23,
 "=" => 24 }

racc_use_result_var = false

racc_nt_base = 25

Racc_arg = [
 racc_action_table,
 racc_action_check,
 racc_action_default,
 racc_action_pointer,
 racc_goto_table,
 racc_goto_check,
 racc_goto_default,
 racc_goto_pointer,
 racc_nt_base,
 racc_reduce_table,
 racc_token_table,
 racc_shift_n,
 racc_reduce_n,
 racc_use_result_var ]

Racc_token_to_s_table = [
'$end',
'error',
'":"',
'REQ',
'NOT',
'AND',
'OR',
'HIGH',
'LOW',
'"^"',
'WORD',
'"("',
'")"',
'"~"',
'WILD_STRING',
'"*"',
'"|"',
'"\""',
'"<"',
'">"',
'"["',
'"]"',
'"}"',
'"{"',
'"="',
'$start',
'top_query',
'bool_query',
'bool_clause',
'query',
'boosted_query',
'term_query',
'field_query',
'phrase_query',
'range_query',
'wild_query',
'field',
'@1',
'@2',
'@3',
'phrase_words']

Racc_debug_parser = false

##### racc system variables end #####

 # reduce 0 omitted

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 19
  def _reduce_1( val, _values)
                    get_boolean_query(val[0])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 24
  def _reduce_2( val, _values)
                    [val[0]]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 28
  def _reduce_3( val, _values)
                    add_and_clause(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 32
  def _reduce_4( val, _values)
                    add_or_clause(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 36
  def _reduce_5( val, _values)
                    add_default_clause(val[0], val[1])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 41
  def _reduce_6( val, _values)
                    get_boolean_clause(val[1], BooleanClause::Occur::MUST)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 45
  def _reduce_7( val, _values)
                    get_boolean_clause(val[1], BooleanClause::Occur::MUST_NOT)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 49
  def _reduce_8( val, _values)
                    get_boolean_clause(val[0], BooleanClause::Occur::SHOULD)
  end
.,.,

 # reduce 9 omitted

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 51
  def _reduce_10( val, _values)
 val[0].boost = val[2].to_f; return val[0]
  end
.,.,

 # reduce 11 omitted

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 58
  def _reduce_12( val, _values)
                    get_boolean_query(val[1])
  end
.,.,

 # reduce 13 omitted

 # reduce 14 omitted

 # reduce 15 omitted

 # reduce 16 omitted

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 67
  def _reduce_17( val, _values)
                    _get_term_query(val[0])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 71
  def _reduce_18( val, _values)
                    _get_fuzzy_query(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 75
  def _reduce_19( val, _values)
                    _get_fuzzy_query(val[0])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 80
  def _reduce_20( val, _values)
                    _get_wild_query(val[0])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 81
  def _reduce_21( val, _values)
@field = @default_field
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 85
  def _reduce_22( val, _values)
                    val[2]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 85
  def _reduce_23( val, _values)
@field = "*"
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 85
  def _reduce_24( val, _values)
@field = @default_field
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 89
  def _reduce_25( val, _values)
                    val[3]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 90
  def _reduce_26( val, _values)
 @field = [val[0]]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 91
  def _reduce_27( val, _values)
 @field = val[0] += [val[2]]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 97
  def _reduce_28( val, _values)
                    get_phrase_query(val[1])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 101
  def _reduce_29( val, _values)
                    get_phrase_query(val[1], val[4].to_i)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 101
  def _reduce_30( val, _values)
 nil
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 102
  def _reduce_31( val, _values)
 nil
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 104
  def _reduce_32( val, _values)
 [val[0]]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 105
  def _reduce_33( val, _values)
 val[0] << val[1]
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 106
  def _reduce_34( val, _values)
 val[0] << nil
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 107
  def _reduce_35( val, _values)
 add_multi_word(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 109
  def _reduce_36( val, _values)
 _get_range_query(val[1], val[2], true, true)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 110
  def _reduce_37( val, _values)
 _get_range_query(val[1], val[2], true, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 111
  def _reduce_38( val, _values)
 _get_range_query(val[1], val[2], false, true)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 112
  def _reduce_39( val, _values)
 _get_range_query(val[1], val[2], false, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 113
  def _reduce_40( val, _values)
 _get_range_query(nil,    val[1], false, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 114
  def _reduce_41( val, _values)
 _get_range_query(nil,    val[1], false, true)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 115
  def _reduce_42( val, _values)
 _get_range_query(val[1], nil,    true, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 116
  def _reduce_43( val, _values)
 _get_range_query(val[1], nil,    false, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 117
  def _reduce_44( val, _values)
 _get_range_query(nil,    val[1], false, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 118
  def _reduce_45( val, _values)
 _get_range_query(nil,    val[2], false, true)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 119
  def _reduce_46( val, _values)
 _get_range_query(val[2], nil,    true, false)
  end
.,.,

module_eval <<'.,.,', 'lib/ferret/query_parser/query_parser.y', 120
  def _reduce_47( val, _values)
 _get_range_query(val[1], nil,    false, false)
  end
.,.,

 def _reduce_none( val, _values)
  val[0]
 end

  end   # class QueryParser

end   # module Ferret


if __FILE__ == $0
  $:.unshift File.join(File.dirname(__FILE__), '..')
  $:.unshift File.join(File.dirname(__FILE__), '../..')
  require 'utils'
  require 'analysis'
  require 'document'
  require 'store'
  require 'index'
  require 'search'

  include Ferret::Search
  include Ferret::Index

  st = "\033[7m"
  en = "\033[m"

  parser = Ferret::QueryParser.new("default",
                                   :fields => ["f1", "f2", "f3"],
                                   :analyzer => Ferret::Analysis::StandardAnalyzer.new,
                                   :handle_parse_errors => true)

  $stdin.each do |line|
    query = parser.parse(line)
    if query
      puts "#{query.class}"
      puts query.to_s(parser.default_field)
    else
      puts "No query was returned"
    end
  end
end
