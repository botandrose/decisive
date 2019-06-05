RSpec.describe Decisive do
  before { Decisive::TemplateHandler.register }

  Record = Struct.new(:a, :b, :c)

  let(:response) { double(headers: {}) }
  let(:controller) { double }

  before do
    @records = [
      Record.new(1,2,3),
      Record.new(4,5,6),
      Record.new(7,8,9),
    ]
  end

  it "works with a yielded record" do
    template = Struct.new(:source).new <<~DECISIVE
      csv @records, filename: "test.csv" do |record|
        column "A"
        column "Badgers", :b
        column "C"
        column "Sum" do
          record.a + record.b + record.c
        end
      end
    DECISIVE

    result = eval(Decisive::TemplateHandler.call(template))

    expect(result).to eq <<~CSV
      A,Badgers,C,Sum
      1,2,3,6
      4,5,6,15
      7,8,9,24
    CSV

    expect(response.headers).to eq({
      "Content-Disposition" => %(attachment; filename="test.csv"),
      "Content-Type" => "text/csv",
      "Content-Transfer-Encoding" => "binary",
    })
  end

  it "works without a yielded record" do
    @records = [
      Record.new(1,2,3),
      Record.new(4,5,6),
      Record.new(7,8,9),
    ]

    template = Struct.new(:source).new <<~DECISIVE
      csv @records, filename: "test.csv" do
        column "A"
        column "Badgers", :b
        column "C"
        column "D", "D"
      end
    DECISIVE

    result = eval(Decisive::TemplateHandler.call(template))

    expect(result).to eq <<~CSV
      A,Badgers,C,D
      1,2,3,D
      4,5,6,D
      7,8,9,D
    CSV

    expect(response.headers).to eq({
      "Content-Disposition" => %(attachment; filename="test.csv"),
      "Content-Type" => "text/csv",
      "Content-Transfer-Encoding" => "binary",
    })
  end
end
