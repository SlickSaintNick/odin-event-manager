# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number_re = phone_number.gsub(/[^0-9]/, '')
  if phone_number_re.length == 10
    format_phone_number(phone_number_re)
  elsif phone_number_re.length == 11 && phone_number_re.start_with?('1')
    format_phone_number(phone_number_re[1, 10])
  else
    '000-000-0000'
  end
end

def format_phone_number(phone_number)
  "#{phone_number[0..2]}-#{phone_number[3..5]}-#{phone_number[6..9]}"
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def display_popular_hours(registration_times, top_n=10)
  puts "The top #{top_n} hours to register were:"
  registration_times
    .map(&:hour)
    .tally
    .sort_by(&:last)
    .reverse[0..(top_n - 1)]
    .each do |data|
      puts "#{data[0]}:00 --> #{data[1]} booking/s"
    end
end

def display_popular_days(registration_times)
  puts "The days of the week with registrations, sorted by frequency, were:"
  registration_times.map{|date| date.wday}.tally.sort_by(&:last).reverse.each do |data|
    puts "#{Date::DAYNAMES[data[0]]} --> #{data[1]}"
  end
end

puts 'Event Manager Initialized!'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
registration_times = []

contents.each do |row|
  id = row[0]
  registration_time = Time.strptime(row[:regdate], '%m/%d/%Y %k:%M')
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  registration_times.push(registration_time)

  puts "#{id} #{name} #{zipcode} #{phone_number}"
end

display_popular_hours(registration_times, 5)
display_popular_days(registration_times)
