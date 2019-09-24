require 'spec_helper'
require 'gds-api-adapters'
require_relative '../../lib/related_links_updater'

require 'json'

describe RelatedLinksUpdater do
  context 'update_related_links' do
    let(:publishing_api) { double }
    let(:publishing_api_response) { double }
    let(:json_file_extractor) { double }

    before do
      extracted_json = JSON.parse('{
          "f593677f-a41f-4ca4-a169-5513a1250125": [
            "a98752a8-2b7c-4b49-896e-5eea396b267e",
            "3c97e19d-a1e5-4800-887d-9ae5d57ad92f",
            "4cc61dfa-2ee6-4263-a4a3-5c852afc8720",
            "de65ab20-c151-489f-afed-57151cb13895",
            "aa8fc376-65c0-4a14-8bc2-1a364f1fed72"
          ],
          "b43584db-0b4b-4d49-9a65-4d4ec42c9394": [
            "ae4c508b-c045-44be-9ccf-dde4555498b1",
            "eb771368-c26d-4519-a964-0769762b3700",
            "12238203-3a7d-400b-90fa-5ae873c43ecf",
            "5e393e14-7631-11e4-a3cb-005056011aef",
            "5e3940ed-7631-11e4-a3cb-005056011aef"
          ],
          "eb771368-c26d-4519-a964-0769762b3700": [
            "3c97e19d-a1e5-4800-887d-9ae5d57ad92f"
          ]
        }')

      allow(json_file_extractor).to receive(:get_batched_keys).with(1).and_return([['f593677f-a41f-4ca4-a169-5513a1250125'], ['b43584db-0b4b-4d49-9a65-4d4ec42c9394'], ['eb771368-c26d-4519-a964-0769762b3700']])
      allow(json_file_extractor).to receive(:get_batched_keys).with(10).and_return([['f593677f-a41f-4ca4-a169-5513a1250125', 'b43584db-0b4b-4d49-9a65-4d4ec42c9394', 'eb771368-c26d-4519-a964-0769762b3700']])
      allow(json_file_extractor).to receive(:extracted_json).and_return(extracted_json)
      allow(publishing_api).to receive(:patch_links).and_return(publishing_api_response)
    end

    it 'should not update related links when there are no related links to update' do
      json_file_extractor = double(:extracted_json => '{}', :get_batched_keys => [])

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      expect(related_links_updater).to_not receive(:update_content)

      related_links_updater.update_related_links
    end

    it 'should call publishing API to update related links and receive success responses' do
      allow(publishing_api_response).to receive(:code).and_return(200)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq([])
    end

    it 'should call publishing API to update related links and receive failed content ids' do
      allow(publishing_api_response).to receive(:code).and_return(500)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq(['f593677f-a41f-4ca4-a169-5513a1250125', 'b43584db-0b4b-4d49-9a65-4d4ec42c9394', 'eb771368-c26d-4519-a964-0769762b3700'])
    end

    it 'should sleep when ingesting links where multiple batches exist' do
      allow(publishing_api_response).to receive(:code).and_return(200)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 1, 5)
      expect(related_links_updater).to receive(:wait).with(5).twice

      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq([])
    end

    it 'should continue calling Publishing API to update related links when patch_links throws a HTTPBadGateway exception' do
      bad_gateway_exception = GdsApi::HTTPBadGateway.new(502, "URL: https://gov.uk, Response body: test, Request body: test", "Request params")

      allow(publishing_api_response).to receive(:code).and_return(200)
      allow(publishing_api).to receive(:patch_links).with('b43584db-0b4b-4d49-9a65-4d4ec42c9394', any_args).and_return(publishing_api_response)
      allow(publishing_api).to receive(:patch_links).with('f593677f-a41f-4ca4-a169-5513a1250125', any_args).and_raise(bad_gateway_exception)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq(['f593677f-a41f-4ca4-a169-5513a1250125'])
    end

    it 'should continue calling Publishing API to update related links when patch_links throws a HTTPUnavailable exception' do
      unavailable_exception = GdsApi::HTTPUnavailable.new(503, "URL: https://gov.uk, Response body: test, Request body: test", "Request params")

      allow(publishing_api_response).to receive(:code).and_return(200)
      allow(publishing_api).to receive(:patch_links).with('b43584db-0b4b-4d49-9a65-4d4ec42c9394', any_args).and_return(publishing_api_response)
      allow(publishing_api).to receive(:patch_links).with('f593677f-a41f-4ca4-a169-5513a1250125', any_args).and_raise(unavailable_exception)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq(['f593677f-a41f-4ca4-a169-5513a1250125'])
    end

    it 'should continue calling Publishing API to update related links when patch_links throws a HTTPGatewayTimeout exception' do
      gateway_timeout_exception = GdsApi::HTTPGatewayTimeout.new(504, "URL: https://gov.uk, Response body: test, Request body: test", "Request params")

      allow(publishing_api_response).to receive(:code).and_return(200)
      allow(publishing_api).to receive(:patch_links).with('b43584db-0b4b-4d49-9a65-4d4ec42c9394', any_args).and_return(publishing_api_response)
      allow(publishing_api).to receive(:patch_links).with('f593677f-a41f-4ca4-a169-5513a1250125', any_args).and_raise(gateway_timeout_exception)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq(['f593677f-a41f-4ca4-a169-5513a1250125'])
    end

    it 'should continue calling Publishing API to update related links when patch_links throws a TimedOutException exception' do
      request_timeout_exception = GdsApi::TimedOutException.new("Timed out reading data from server")

      allow(publishing_api_response).to receive(:code).and_return(200)
      allow(publishing_api).to receive(:patch_links).with('b43584db-0b4b-4d49-9a65-4d4ec42c9394', any_args).and_return(publishing_api_response)
      allow(publishing_api).to receive(:patch_links).with('f593677f-a41f-4ca4-a169-5513a1250125', any_args).and_raise(request_timeout_exception)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq(['f593677f-a41f-4ca4-a169-5513a1250125'])
    end

    it 'should continue calling Publishing API to update related links when patch_links throws multiple exceptions' do
      gateway_timeout_exception = GdsApi::HTTPGatewayTimeout.new(504, "URL: https://gov.uk, Response body: test, Request body: test", "Request params")
      request_timeout_exception = GdsApi::TimedOutException.new("Timed out reading data from server")

      allow(publishing_api_response).to receive(:code).and_return(200)
      allow(publishing_api).to receive(:patch_links).with('eb771368-c26d-4519-a964-0769762b3700', any_args).and_return(publishing_api_response)
      allow(publishing_api).to receive(:patch_links).with('f593677f-a41f-4ca4-a169-5513a1250125', any_args).and_raise(gateway_timeout_exception)
      allow(publishing_api).to receive(:patch_links).with('b43584db-0b4b-4d49-9a65-4d4ec42c9394', any_args).and_raise(request_timeout_exception)

      related_links_updater = RelatedLinksUpdater.new(publishing_api, json_file_extractor, 10)
      related_links_updater.update_related_links

      expect(related_links_updater.failed_content_ids).to eq(%w(f593677f-a41f-4ca4-a169-5513a1250125 b43584db-0b4b-4d49-9a65-4d4ec42c9394))
    end
  end
end
