RSpec.describe Decisive do
  before { Decisive::TemplateHandler.register }

  Record = Struct.new(:a, :b, :c)

  let(:response) { double(headers: {}) }

  it "works" do
    @records = [
      Record.new(1,2,3),
      Record.new(4,5,6),
      Record.new(7,8,9),
    ]

    template = Struct.new(:source).new <<~DECISIVE
      @filename = "test.csv"
      column :a
      column :b
      column :c
    DECISIVE

    result = eval(Decisive::TemplateHandler.call(template))

    expect(result).to eq <<~CSV
      A,B,C
      1,2,3
      4,5,6
      7,8,9
    CSV

    expect(response.headers).to eq({
      "Content-Disposition" => %(attachment; filename="test.csv")
    })
  end
end
