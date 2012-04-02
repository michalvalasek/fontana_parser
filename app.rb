#!/usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'sqldsl'

class FontanaParser

  attr_accessor :next_event_id

  def initialize(next_event_id = nil)
    @next_event_id ||= 1
  end

  def run
    puts "Parsing fontana-piestany.sk index page..."
    today = Time.now.strftime("%Y-%m-%d")
    output_file = File.open("storage/program_#{today}.sql",'w')
    doc = Nokogiri::HTML(open('http://fontana-piestany.sk'))
    doc.css('#content .main_title a').each do |link|
      page_url = link[:href]
      if page_url =~ /\/program-kina\//
        data = parse_page(page_url)
        output_file.write generate_sql(data) + "\n"
      end
    end
    puts "index parsed, output written to storage/program_#{today}.sql"
    output_file.close
  end

  def parse_page(url)
    puts "Parsing page #{url}..."
    data = {}
    doc = Nokogiri::HTML(open(url))
    title = doc.css("#content h1").first.content.scan(/(.*) \((.*)\)/)
    data[:title] = title[0][0]
    data[:title_orig] = title[0][1]
    data[:description] = doc.css("#content .content_text div")[1].css("p").first.content
    paragraphs = doc.css("#content .content_text p")
    data[:info] = paragraphs[4].content + paragraphs[5].content
    data[:type] = paragraphs[3].content.gsub(/\s\[.*\]/,"") +" "+ paragraphs[2].css("b").first.content
    data[:dates] = []
    doc.css("#content .content_text p")[0].content.scan(/(\d{2})\.(\d{2})\.(\d{4}) o (\d{2}):(\d{2})/).each do |date|
      datetime = Time.new(date[2],date[1],date[0],date[3],date[4])
      data[:dates] << {:date => datetime.strftime("%Y%m%d"), :timestamp=>datetime.to_i}
    end
    data
  end

  def generate_sql(data)
    event_id = @next_event_id
    @next_event_id += 1
    sql = Insert.into[:events][:id, :title, :title_orig, :description, :info, :type].values(
      event_id,
      data[:title],
      data[:title_orig],
      data[:description],
      data[:info],
      data[:type]
    ).to_sql + ";\n"
    data[:dates].each do |date|
      sql += Insert.into[:dates][:event_id, :date, :timestamp].values(event_id, date[:date], date[:timestamp]).to_sql + ";\n"
    end
    sql
  end
end 

parser = FontanaParser.new()
parser.next_event_id = 46
parser.run
