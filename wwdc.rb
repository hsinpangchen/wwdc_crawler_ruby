
require 'nokogiri'
require 'open-uri'
require 'json'


def fetch_topics(url)

  doc = Nokogiri::HTML(open(url))


  topics = []

  doc.css("div.topics-container div.column").each_with_index do |topic_row, index|

    topic = {}


    topic_name = topic_row.css("a h4").text
    topic[:name] = topic_name
    topic[:url] = topic_row.css("a").attr("href").value
    topic[:type] = "topic"
    puts topic

    topic[:children] = []

    topic_row.css("ul li").each do |child_topic_row|

      child_topic = {}
      child_topic_name = child_topic_row.css("a").text.gsub!("\t","").gsub!("\n","")
      child_topic[:name] = child_topic_name
      child_topic[:url] = child_topic_row.css("a").attr("href").value
      child_topic[:type] = "topic"
      topic[:children] << child_topic

    end

    topics << topic


  end

  # File.open("sections.json",'wb') do |file|
  #     file << JSON.pretty_generate(topics)
  # end

  topics

end


def fetch_video(url, topic_name)

  doc = Nokogiri::HTML(open(url))

  videos = []

  doc.css("li.collection-item section.column").each_with_index do |video_row, index|

    video = {}

    video_url = video_row.css("a").attr("href").value
    video[:url] = video_url

    next unless video_url.include?("2018")

    video_title = video_row.css("a").text.gsub!("\t","").gsub!("\n","")
    video[:title] = video_title

    next unless video_title.size > 0 #trim photo preview row

    #platform
    video_row.css("ul.video-tags li.focus").each do |platform|
      video[:platform] = platform.text
    end

    video_content = video_row.css("p").text
    video[:content] = video_content
    video[:type] = "video"
    video[:parent_topic] = topic_name

    videos << video

  end

  # File.open("videos.json",'wb') do |file|
  #     file << JSON.pretty_generate(videos)
  # end

  videos
end


#

def fetch_wwdc_json

  host = "https://developer.apple.com"

  topic_url = host + "/videos/topics/"

  topics = fetch_topics(topic_url)

  topics.each do |topic|

    next unless topic[:children].size > 0

    sub_topics = topic[:children]
    puts "."

    sub_topics.each do |child|
      child_url = host + child[:url]
      videos = fetch_video(child_url, child[:name])
      child[:videos] = videos.sort_by{ |k| k[:url]}
    end
  end

  return topics

end

def find_topics_in_wwdc_by_video_url(wwdc, video_url)

  txt_topics = []

  wwdc.each do |topic|

    next unless topic[:children].size > 0
    sub_topics = topic[:children]

    sub_topics.each do |sub_topic|

      sub_topic[:videos].each do |video|
        if video[:url] == video_url
          txt_topics << video[:parent_topic]
        end
      end

    end


  end

  txt_topics

end


def generate_md(videos, sorted_by_alphabetical)

  md = ""
  host = "https://developer.apple.com"

  filename = "./example/wwdc.md"

  if sorted_by_alphabetical
    videos = videos.sort_by{ |k| k[:title]}
    filename = "./example/wwdc_sorted_by_alphabetical.md"
  end


  videos.each do |video|
    md << "## " + video[:title] + "\n"
    md << "platform : " + video[:platform] + "\n\n"
    md << "topics : " + video[:topics].join("/") + "\n\n"
    md << video[:content] + "\n\n"
    md << "[link](" + host + video[:url] + ")" + "\n\n"
    md << "\n"
  end

  File.open(filename,'wb+') do |file|
      file << md
  end

end



def fetch_all_videos

  directory_name = "example"
  Dir.mkdir(directory_name) unless File.exists?(directory_name)

  topics = fetch_wwdc_json

  File.open("./example/wwdc.json",'wb+') do |file|
      file << JSON.pretty_generate(topics)
  end


  # generate vidoe list

  videos = []
  video_string_array = []
  topics.each do |topic|

    next unless topic[:children].size > 0

    sub_topics = topic[:children]

    sub_topics.each do |child|

      child[:videos].each do |video|

        video_url = video[:url]
        unless video_string_array.include?(video_url)
          videos << video
          video_string_array << video_url
        end

      end

    end
  end

  # sort videos
  videos = videos.sort_by{ |k| k[:url]}



  # combine topic and video
  videos.each do |video|

    topics_text = find_topics_in_wwdc_by_video_url(topics, video[:url])
    video[:topics] = topics_text
    video.delete(:parent_topic)

  end

  File.open("./example/wwdc_videos.json",'wb+') do |file|
      file << JSON.pretty_generate(videos)
  end

  generate_md(videos, false)
  generate_md(videos, true)




end









fetch_all_videos
