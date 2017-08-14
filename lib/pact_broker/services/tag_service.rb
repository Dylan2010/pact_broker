require 'pact_broker/repositories'
require 'pact_broker/services'

module PactBroker

  module Services
    module TagService

      extend self

      extend PactBroker::Repositories

      extend PactBroker::Services

      def create args
        # create tag depends on consumer name and version
        logger.info "begin create tag #{args}"
        pacticipant = pacticipant_repository.find_by_name_or_create args.fetch(:pacticipant_name)
        version = version_repository.find_by_pacticipant_id_and_number_or_create pacticipant.id, args.fetch(:pacticipant_version_number)
        begin
          # get all provider
          comparearray = Array.new
          group = group_service.find_group_containing pacticipant
          if group.present?
            group.each { |x| fillCompareArray x.consumer.name,x.provider.name,version.number,args.fetch(:tag_name),comparearray }
            if comparearray.present?
              # construct post data
              postdata = {:tagArgs => args,:compareArray => comparearray}
              postdatajson = JSON.generate(postdata)
              # http post
              uri = URI.parse("http://pact-compare.smec/pact/compare")
              header = {"Content-Type"=>'application/json'}
              # Create the HTTP objects
              http = Net::HTTP.new(uri.host, uri.port)
              request = Net::HTTP::Post.new(uri.request_uri, header)
              request.body = postdatajson
              # Send the request
              response = http.request(request)
              compareFailArray = JSON.parse(response.body)
              if !compareFailArray.present?
                logger.info "compare pacts passed"
              else
                logger.warn "compare pacts failed. args:#{args}"
              end
            end
          end
        rescue => err
          logger.error err
        end
        tag_repository.create version: version, name: args.fetch(:tag_name)
      end

      def find args
        logger.info "find tag #{args}"
        tag_repository.find args
      end

      def fillCompareArray consumer_name,provider_name,version,tag,compareArray
        #find pact by version
        param = {consumer_name:consumer_name,provider_name:provider_name,consumer_version_number:version}
        pactByVersion = pact_service.find_pact param
        #find latest pact in tag
        param = {consumer_name:consumer_name,provider_name:provider_name,tag:tag}
        pactByTag = pact_service.find_latest_pact param
        if pactByVersion && pactByTag
          #use old pact with same tag as reference
          logger.info "compare pact with tag #{tag} with pact with #{version} between consumer #{consumer_name} and provider #{provider_name}"
          compareArray.push pactByTag
          compareArray.push pactByVersion
        end
      end

    end
  end

end
