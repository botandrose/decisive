require "fileutils"
require "./spec/support/xls_hasher"

RSpec.describe Decisive do
  before { Decisive::TemplateHandler.register }

  Record = Struct.new(:a, :b, :c)

  before { stub_const "Rails", double(env: double(test?: false)) }

  let(:response) { double(headers: {}, stream: double) }
  let(:controller) { double }

  context "#xls" do
    before do
      @worksheets = {
        "Ones" => [
          Record.new(1,2,3),
          Record.new(4,5,6),
          Record.new(7,8,9),
        ],
        "Teens" => [
          Record.new(11,12,13),
          Record.new(14,15,16),
          Record.new(17,18,19),
        ],
      }
    end

    it "works without yielding records" do
      template = Struct.new(:source).new <<~DECISIVE
        xls @worksheets, filename: "test.xls" do
          column "A"
          column "Badgers", :b
          column "C"
          column "D", "D"
        end
      DECISIVE

      FileUtils.mkdir_p "tmp"
      path = "tmp/result.xls"
      result = eval(Decisive::TemplateHandler.call(template))
      File.open(path, "wb") { |io| io.write(result) }

      expect(XLSHasher.new(path).to_hash).to eq({
        "Ones" => [
          ["A","Badgers","C","D"],
          ["1","2","3","D"],
          ["4","5","6","D"],
          ["7","8","9","D"],
        ],
        "Teens" => [
          ["A","Badgers","C","D"],
          ["11","12","13","D"],
          ["14","15","16","D"],
          ["17","18","19","D"],
        ],
      })

      expect(response.headers).to eq({
        "Content-Disposition" => %(attachment; filename="test.xls"),
        "Content-Type" => "application/vnd.ms-excel",
        "Content-Transfer-Encoding" => "binary",
      })
    end
  end
end