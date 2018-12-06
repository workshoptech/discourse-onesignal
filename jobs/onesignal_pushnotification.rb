module Jobs
  class OnesignalPushnotification < Jobs::Base
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'.freeze

    def execute(args)
      payload = args['payload']

      # The user who should receive the notification
      acted_on_user = args['user']
      # The user who took action to trigger the notification
      actor_user = User.find_by(username: payload[:username])

      # Get the most recent post in the topic for which the notification was
      # triggered which is from the actor user. This is the post for which
      # we want to show the notification
      topic = Topic.find(payload[:topic_id])
      post = topic.posts.where(user_id: actor_user.id).last

      # Build the correct notification heading
      heading = actor_user.name

      # If the post is a reply and the user of that post is the acted_on_user
      if post.reply_to_post_number? && post.reply_to_user_id == acted_on_user.id
        # Replied to your comment
        if post.archetype == 'regular'
          heading = "#{actor_user.name} replied to your comment"
        end
        # Replied to your message (replied to you)
      elsif topic.user_id == acted_on_user.id
        # if original poster on topic is acted_on_user
        # Commented on your post (if acted_on_user is post user)
        if post.archetype == 'regular'
          heading = "#{actor_user.name} commented on your post"
        end
        # if archetype is private_message
        # Just carry on
      else
        return
      end

      params = {
        'app_id' => SiteSetting.onesignal_app_id,
        'contents' => { 'en' => post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true) },
        'headings' => { 'en' => heading },
        'data' => payload,
        'ios_badgeType' => 'Increase',
        'ios_badgeCount' => '1',
        'filters' => [
          { "field": 'tag', "key": 'username', "relation": '=', "value": args['username'] }
        ]
      }

      uri = URI.parse(ONESIGNALAPI)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'

      request = Net::HTTP::Post.new(uri.path,
                                    'Content-Type' => 'application/json;charset=utf-8',
                                    'Authorization' => "Basic #{SiteSetting.onesignal_rest_api_key}")
      request.body = params.as_json.to_json
      response = http.request(request)

      case response
      when Net::HTTPSuccess then
        Rails.logger.info("Push notification sent via OneSignal to #{args['username']}.")
      else
        Rails.logger.error('OneSignal error')
        Rails.logger.error(request.to_yaml.to_s)
        Rails.logger.error(response.to_yaml.to_s)

      end
      end
  end
  end
