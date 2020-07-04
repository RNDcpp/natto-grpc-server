# frozen_string_literal: true

require 'grpc'
require 'mecab_services_pb'
require 'natto'

NEOLOGD_PATH = ENV.fetch('NEOLOGD_PATH')

# return Natto::MeCab.parse responces as stream
class MecabNodeEnum
  def initialize(request_string)
    @input_string = request_string.body
    @nm = Natto::MeCab.new("-d #{NEOLOGD_PATH}")
    @response_list = @nm.enum_parse(@input_string).map(&mecab_node_2_response_node_proc)
  end

  def each
    return enum_for(:each) unless block_given?

    @response_list.each do |response|
      yield response
    end
  end

  private

  def mecab_node_2_response_node_proc
    lambda do |mecab_node|
      Mecabgrpc::ResponseNode.new(
        surface:   mecab_node.surface,
        feature:   mecab_node.feature,
        id:        mecab_node[:id],
        length:    mecab_node[:length],
        rlength:   mecab_node[:rlength],
        rcAttr:    mecab_node[:rcAttr],
        lcAttr:    mecab_node[:lcAttr],
        posid:     mecab_node[:posid],
        char_type: mecab_node[:char_type],
        stat:      mecab_node[:stat],
        isbest:    mecab_node[:isbest],
        alpha:     mecab_node[:alpha],
        beta:      mecab_node[:beta],
        prob:      mecab_node[:prob],
        wcost:     mecab_node[:wcost],
        cost:      mecab_node[:cost]
      )
    end
  end
end

# mecab grpc server
class MecabServer
  class << self
    def start
      port = '0.0.0.0:8000'
      @server = GRPC::RpcServer.new
      @server.add_http2_port(port, :this_port_is_insecure)
      @server.handle(AppService.new)
      GRPC.logger.info("... running insecurely on #{port}")
      @server.run_till_terminated
    end
  end
end

# mecab service
class AppService < Mecabgrpc::MecabService::Service
  def parse(request_string, _unused_call)
    MecabNodeEnum.new(request_string).each
  end
end

MecabServer.start
