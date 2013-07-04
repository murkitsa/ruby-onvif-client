require_relative '../action'

module ONVIF
    module MediaAction
        class GetProfiles < Action
            def run cb
                message = Message.new
                message.body = ->(xml) do
                    xml.wsdl(:GetProfiles)
                end
                send_message message do |success, result|
                    if success
                        xml_doc = Nokogiri::XML(result[:content])
                        profiles = []
                        xml_doc.xpath('//trt:Profiles').each do |root_node|
                            video_source = root_node.at_xpath("tt:VideoSourceConfiguration")
                            audio_source = root_node.at_xpath("tt:AudioSourceConfiguration")
                            video_encoder = root_node.at_xpath("tt:VideoEncoderConfiguration")
                            audio_encoder = root_node.at_xpath("tt:AudioEncoderConfiguration")
                            video_analytics = root_node.at_xpath("tt:VideoAnalyticsConfiguration")
                            ptz = root_node.at_xpath("tt:PTZConfiguration")
                            metadata = root_node.at_xpath("tt:MetadataConfiguration")
                            success_result = {
                                name: _get_name(root_node),
                                token: _get_token(root_node),
                                fixed: attribute(root_node, "fixed"),
                                extension: ""
                            }
                            success_result["video_source_configuration"] = _get_video_source_configuration(video_source) unless video_source.nil?
                            success_result["audio_source_configuration"] = _get_audio_source_configuration(audio_source) unless audio_source.nil?
                            success_result["video_encoder_configuration"] = _get_video_encoder_configuration(video_encoder) unless video_encoder.nil?
                            success_result["audio_encoder_configuration"] = _get_audio_encoder_configuration(audio_encoder) unless audio_encoder.nil?
                            success_result["video_analytics_configuration"] = _get_video_analytics_configuration(video_analytics) unless video_analytics.nil?
                            success_result["ptz_configuration"] = _get_ptz_configuration(ptz) unless ptz.nil?
                            success_result["metadata_configuration"] = _get_metadata_configuration(metadata) unless metadata.nil?
                            profiles << success_result
                        end
                        callback cb, success, profiles
                    else
                        callback cb, success, result
                    end
                end
            end
            
            def _get_node parent_node, node_name
                parent_node.at_xpath(node_name)
            end
            def _get_name parent_node
                value(parent_node, "tt:Name")
            end
            def _get_use_count parent_node
                value(parent_node, "tt:UseCount")
            end
            def _get_token parent_node
                attribute(parent_node, "token")
            end
            def _get_min_max xml_doc, parent_name
                this_node = xml_doc
                unless parent_name.nil?
                    this_node = xml_doc.at_xpath(parent_name)
                end
                return {
                    min: value(this_node, "tt:Min"),
                    max: value(this_node, "tt:Max")
                }
            end
            def _get_public_sector parent_node
                {
                    name: _get_name(parent_node),
                    token: _get_token(parent_node),
                    use_count: _get_use_count(parent_node)
                }
            end

            def _get_video_source_configuration parent_node
                configuration = _get_public_sector(parent_node)
                configuration["source_token"] = value(parent_node, "tt:SourceToken")
                bounds = parent_node.at_xpath("tt:Bounds")
                configuration["bounds"] = {
                    x: attribute(bounds, "x"),
                    y: attribute(bounds, "y"),
                    width: attribute(bounds, "width"),
                    height: attribute(bounds, "height")
                }
                return configuration
            end

            def _get_audio_source_configuration parent_node
                configuration = _get_public_sector(parent_node)
                configuration["source_token"] = value(parent_node, "tt:SourceToken")
                return configuration
            end

            def _get_video_encoder_configuration parent_node
                configuration = _get_public_sector(parent_node)
                configuration["encoding"] = value(parent_node, "tt:Encoding")
                configuration["resolution"] = {
                    width: value(_get_node(parent_node, "tt:Resolution"), "tt:Width"),
                    height: value(_get_node(parent_node, "tt:Resolution"), "tt:Height")
                }
                configuration["quality"] = value(parent_node, "tt:Quality")
                configuration["rate_control"] = {
                    frame_rate_limit: value(_get_node(parent_node, "tt:RateControl"), "tt:FrameRateLimit"),
                    encoding_interval: value(_get_node(parent_node, "tt:RateControl"), "tt:EncodingInterval"),
                    bitrate_limit: value(_get_node(parent_node, "tt:RateControl"), "tt:BitrateLimit")
                }
                unless parent_node.at_xpath('//tt:MPEG4').nil?
                    configuration["MPEG4"] = {
                        gov_length:  value(_get_node(parent_node, "tt:MPEG4"), "tt:GovLength"),
                        mpeg4_profile:  value(_get_node(parent_node, "tt:MPEG4"), "tt:Mpeg4Profile")
                    }
                end
                unless parent_node.at_xpath('//tt:H264').nil?
                    configuration["H264"] = {
                        gov_length:  value(_get_node(parent_node, "tt:H264"), "tt:GovLength"),
                        h264_profile:  value(_get_node(parent_node, "tt:H264"), "tt:H264Profile")
                    }
                end
                configuration["multicast"] = _get_multicast(parent_node)
                configuration["session_timeout"] = value(parent_node, "tt:SessionTimeout")
                return configuration
            end

            def _get_audio_encoder_configuration parent_node
                configuration = _get_public_sector(parent_node)
                configuration["encoding"] = value(parent_node, "tt:Encoding")
                configuration["bitrate"] = value(parent_node, "tt:Bitrate")
                configuration["sample_rate"] = value(parent_node, "tt:SampleRate")
                configuration["multicast"] = _get_multicast(parent_node)
                configuration["session_timeout"] = value(parent_node, "tt:SessionTimeout")
                return configuration
            end

            def _get_video_analytics_configuration parent_node
                configuration = _get_public_sector(parent_node)
                analytics_module = []; rule = []
                parent_node.at_xpath("tt:AnalyticsEngineConfiguration//tt:AnalyticsModule").each do |node|
                    analytics_module << {
                        name: attribute(node, "Name"),
                        type: attribute(node, "Type"),
                        parameters: _get_parameters(node)
                    }
                end
                parent_node.at_xpath("tt:AnalyticsEngineConfiguration//tt:RuleEngineConfiguration").each do |node|
                    rule << {
                        name: attribute(node, "Name"),
                        type: attribute(node, "Type"),
                        parameters: _get_parameters(node)
                    }
                end
                configuration["analytics_engine_configuration"] = {
                    analytics_module: analytics_module,
                    extension: ""
                }
                configuration["rule_engine_configuration"] = {
                    rule: rule,
                    extension: ""
                }
                return configuration
            end

            def _get_ptz_configuration parent_node
                configuration = _get_public_sector(parent_node)
                configuration["node_token"] = value(parent_node, "tt:NodeToken")
                configuration["default_absolute_pant_tilt_position_space"] = value(parent_node, "tt:DefaultAbsolutePantTiltPositionSpace")
                configuration["default_absolute_zoom_position_space"] = value(parent_node, "tt:DefaultAbsoluteZoomPositionSpace")
                configuration["default_relative_pan_tilt_translation_space"] = value(parent_node, "tt:DefaultRelativePanTiltTranslationSpace")
                configuration["default_relative_zoom_translation_space"] = value(parent_node, "tt:DefaultRelativeZoomTranslationSpace")
                configuration["default_continuous_pan_tilt_velocity_space"] = value(parent_node, "tt:DefaultContinuousPanTiltVelocitySpace")
                configuration["default_continuous_zoom_velocity_space"] = value(parent_node, "tt:DefaultContinuousZoomVelocitySpace")
                pan_tilt = _get_node(parent_node,"//tt:DefaultPTZSpeed//tt:PanTilt")
                zoom = _get_node(parent_node,"//tt:DefaultPTZSpeed//tt:Zoom")
                configuration["default_ptz_speed"] = {
                    pan_tilt:{
                        x: attribute(pan_tilt, "x"),
                        y: attribute(pan_tilt, "y"),
                        space: attribute(pan_tilt, "space")
                    },
                    zoom: {
                        x: attribute(zoom, "x"),
                        space: attribute(zoom, "space")
                    }
                }
                configuration["fefault_ptz_timeout"] = value(parent_node, "tt:DefaultPTZTimeout")
                configuration["pan_tilt_limits"] = {
                    range: {
                        uri: value(_get_node(parent_node, "tt:PanTiltLimits//tt:Range"), "tt:URI"),
                        x_range: _get_min_max(_get_node(parent_node,"tt:PanTiltLimits//tt:Range"), "tt:XRange"),
                        y_range: _get_min_max(_get_node(parent_node,"tt:PanTiltLimits//tt:Range"), "tt:YRange")
                    }
                }
                configuration["zoom_limits"] = {
                    range: {
                        uri: value(_get_node(parent_node, "tt:PanTiltLimits//tt:Range"), "tt:URI"),
                        x_range: _get_min_max(_get_node(parent_node,"tt:PanTiltLimits//tt:Range"), "tt:XRange"),
                    }
                }
                configuration["extension"] = ""
                return configuration
            end

            def _get_metadata_configuration parent_node
                configuration = _get_public_sector(parent_node)
                configuration["ptz_status"] = {
                    status: value(_get_node(parent_node, "tt:PTZStatus"), "tt:Status"),
                    sosition: value(_get_node(parent_node, "tt:PTZStatus"), "tt:Position")
                }
                configuration["events"] = {
                    filter: value(_get_node(parent_node, "tt:Events"), "tt:Filter"),
                    subscription_policy: value(_get_node(parent_node, "tt:Events"), "tt:SubscriptionPolicy")
                }
                configuration["analytics"] = value(parent_node, "tt:Analytics")
                configuration["multicast"] = _get_multicast(parent_node)
                configuration["session_timeout"] = value(parent_node, "tt:SessionTimeout")
                unless parent_node.at_xpath("tt:AnalyticsEngineConfiguration//tt:AnalyticsModule").nil?
                    analytics_module = []
                    parent_node.at_xpath("tt:AnalyticsEngineConfiguration//tt:AnalyticsModule").each do |node|
                        analytics_module << {
                            name: attribute(node, "Name"),
                            type: attribute(node, "Type"),
                            parameters: _get_parameters(node)
                        }
                    end
                    configuration["analytics_engine_configuration"] = {
                        analytics_module: analytics_module,
                        extension: ""
                    }
                end
                configuration["extension"] = ""
                return configuration
            end

            def _get_multicast parent_node
                {
                    address: {
                        type: value(_get_node(parent_node, "//tt:Multicast//tt:Address"), '//tt:Type'),
                        ipv4_address: value(_get_node(parent_node, "//tt:Multicast//tt:Address"), '//tt:IPv4Address'),
                        ipv6_address: value(_get_node(parent_node, "//tt:Multicast//tt:Address"), '//tt:IPv6Address')
                    },
                    port: value(_get_node(parent_node, "//tt:Multicast"), "tt:Port"),
                    ttl: value(_get_node(parent_node, "//tt:Multicast"), "tt:TTL"),
                    auto_start: value(_get_node(parent_node, "//tt:Multicast"), "tt:AutoStart")
                }
            end

            def _get_parameters parent_node
                simple_item = []
                element_item = []
                parent_node.at_xpath("tt:SimpleItem").each do |node|
                    simple_item << {
                        name: attribute(node, "Name"),
                        value: attribute(node, "Value")
                    }
                end
                parent_node.at_xpath("tt:ElementItem").each do |node|
                    element_item << {
                        xsd_any: value(node, "tt:xsd:any"),
                        name:  attribute(node, "Name")
                    }
                end
                return {
                    simple_item: simple_item,
                    element_item: element_item,
                    extension: ""
                }
            end
        end
    end
end
