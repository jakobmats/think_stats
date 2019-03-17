require 'zlib'
require 'stringio'
require 'ostruct'

# "Think stats" 1.3
# Rewrite of survey.py
module ThinkStats
  Respondent = Class.new(OpenStruct)
  Pregnancy = Class.new(OpenStruct)

  # Table mixin
  module Table

    # Retrieve records from file
    # @param [String] file_name
    def from_file(file_name)
      data = File.read(file_name)
      data = Zlib::GzipReader.new(StringIO.new(data)).read if file_name.end_with?('.gz')

      data.lines.each do |l|
        @records << make_record(l)
      end
    end

    # Add record to table
    # @param [Object] record
    def <<(record)
      @records << record
    end


    # Retrieve specific record
    # @param [Integer] index
    def [](index)
      @records[index]
    end

    # Extend table with new records
    # @param [Array<Object>] records
    def extend(records)
      @records += records
    end

    # Table length
    # @return [Integer]
    def length
      @records.length
    end

    private

    # Create new record
    # @param [Object] line
    # @return [Object]
    def make_record(line)
      record = @klass.new
      @fields.each do |field, start, stop, cast|
        begin
          val = line[start-1...stop].send(cast)
        rescue NoMethodError
          val = 'NA'
        end

        record[field] = val
      end

      if @recode.nil? then record else @recode.call(record) end
    end
  end

  class RecordTable
    include Table

    def initialize(klass, fields, recode: nil)
      @records = []
      @klass = klass
      @fields = fields
      @recode = recode
    end
  end
end

respondents = ThinkStats::RecordTable.new(ThinkStats::Respondent, [
    [:caseid, 1, 12, :to_i]
])
respondents.from_file(File.expand_path('2002FemResp.dat.gz', __dir__))

pregnancies = ThinkStats::RecordTable.new(ThinkStats::Pregnancy, [
    [:caseid, 1, 12, :to_i],
    [:nbrnaliv, 22, 22, :to_i],
    [:babysex, 56, 56, :to_i],
    [:birthwgt_lb, 57, 58, :to_i],
    [:birthwgt_oz, 59, 60, :to_i],
    [:prglength, 275, 276, :to_i],
    [:outcome, 277, 277, :to_i],
    [:birthord, 278, 279, :to_i],
    [:agepreg, 284, 287, :to_i],
    [:finalwgt, 423, 440, :to_f]
], recode: lambda do |record|
  if record.agepreg != 'NA'
    record.agepreg /= 100.0
  end

  if record.birthwgt_lb != 'NA' && record.birthwgt_lb < 20 &&
      record.birthwgt_oz != 'NA' && record.birthwgt_oz <= 16
      record.totalwgt_oz = record.birthwgt_lb * 16 + record.birthwgt_oz
  else
      record.totalwgt_oz = 'NA'
  end

  record
end)
pregnancies.from_file(File.expand_path('2002FemPreg.dat.gz', __dir__))

puts "Number of respondents: #{respondents.length}"
puts "Number of pregnancies: #{pregnancies.length}"
