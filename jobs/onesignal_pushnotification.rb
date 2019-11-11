module Jobs
  class OnesignalPushnotification < Jobs::Base
    ONESIGNALAPI = 'https://onesignal.com/api/v1/notifications'.freeze

    def execute(args)
      payload = args['payload']

      # The user who should receive the notification
      acted_on_user = User.find_by(username: args[:username])
      # The user who took action to trigger the notification
      actor_user = User.find_by(username: payload[:username])

      Rails.logger.warn("Acted On User: #{acted_on_user.username}")
      Rails.logger.warn("Actor User: #{actor_user.username}")

      # Get the most recent post in the topic for which the notification was
      # triggered which is from the actor user. This is the post for which
      # we want to show the notification
      topic = Topic.find(payload[:topic_id])
      post = topic.posts.where(user_id: actor_user.id).last

      # Build the correct notification heading
      heading = actor_user.name

      user_id = nil
      user_id = acted_on_user.id unless acted_on_user.nil?

      # Attempt to extract course related information
      course_title = nil
      subtitle = nil
      icon_name = nil
      if topic.category_id?
        # If a category exists, we can extract the course slug from it. Note that
        # it's normal to have one level of nesting on the category which the topic
        # is associated to, but this isn't always the case.
        category = Category.find(topic.category_id)

        if category.parent_category_id?
          parent = Category.find(category.parent_category_id)
          course_title = parent.name
        else
          course_title = category.name
        end
      end

      Rails.logger.warn("Archetype: #{post.archetype}")

      redirect_uri = 'Explore'
      # If the post is a reply and the user of that post is the acted_on_user
      # and the post is specifically not a PM
      if post.archetype != Archetype.private_message && post.reply_to_post_number? && post.reply_to_user_id == user_id
        # Replied to your comment
        if post.archetype == Archetype.default
          redirect_uri = 'FeedbackTopic'
          subtitle = 'Post Feedback'
          if payload[:notification_type] == Notification.types[:replied]
            heading = 'New reply to your comment'
          elsif payload[:notification_type] == Notification.types[:liked]
            heading = "#{actor_user.name} liked your comment"
          end
        end
      # Replied to your message (replied to you) and the post is specifically 
      # not a PM
      elsif post.archetype != Archetype.private_message && topic.user_id == user_id
        # if original poster on topic is acted_on_user
        # Commented on your post (if acted_on_user is post user)
        if post.archetype == Archetype.default
          redirect_uri = 'FeedbackTopic'
          subtitle = 'Post Feedback'
          if payload[:notification_type] == Notification.types[:posted]
            heading = 'New comment on your post'
          elsif payload[:notification_type] == Notification.types[:liked]
            heading = "#{actor_user.name} liked your post"
          end
        end
      elsif post.archetype == Archetype.private_message
        # if archetype is private_message
        redirect_uri = 'PrivateMessage'
        # If it's a private message we need to determine whether it's:
        # - A private message between 2 students (default assumption)
        # - A group chat message
        # - A support chat message
        subtitle = heading

        # Is it a group chat?
        if topic.title.include? 'Group Chat'
          subtitle = 'Class Discussion'
          icon_name = 'group'
        end

        # Is it a support message?
        if actor_user.username == 'workshop_support'
          subtitle = 'Workshop Support'
          icon_name = 'help-outline'
        end
      end

      # We never want to show the system user as a heading
      heading = 'Workshop' if heading == 'system'

      # Format the contents - if the notification is for a post on a topic,
      # include the users name in the contents of the notification.
      contents = post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true)

      if redirect_uri == 'FeedbackTopic'
        contents = "#{actor_user.name}: #{post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true)}"
      end

      # Create the filters map
      filters = [
        { "field": 'tag', "key": 'username', "relation": '=', "value": args['username'] },
        { "field": 'tag', "key": 'env', "relation": '=', "value": SiteSetting.onesignal_env_string }
      ]

      # Only send certain notification types if the user has those types enabled
      if payload[:notification_type] == Notification.types[:replied]
        filters.push("field": 'tag', "key": 'repliedNotificationEnabled', "relation": '=', "value": 'true')
      elsif payload[:notification_type] == Notification.types[:posted]
        filters.push("field": 'tag', "key": 'postedNotificationEnabled', "relation": '=', "value": 'true')
      elsif payload[:notification_type] == Notification.types[:private_message]
        filters.push("field": 'tag', "key": 'privateMessageNotificationEnabled', "relation": '=', "value": 'true')
      end

      params = {
        'app_id' => SiteSetting.onesignal_app_id,
        'contents' => { 'en' => contents },
        'headings' => { 'en' => heading },
        'data' => payload.merge('redirectUri' => redirect_uri, 'redirectProps' => { 'title' => course_title, 'subtitle': subtitle, 'icon': icon_name }),
        'ios_badgeType' => 'Increase',
        'ios_badgeCount' => '1',
        'android_group' => "cohort_notifications_#{payload[:topic_id]}",
        'filters' => filters
      }

      Rails.logger.warn("Params Built")
      Rails.logger.warn("#{params.to_yaml}")

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
