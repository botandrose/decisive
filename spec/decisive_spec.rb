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
      csv @records, filename: "test.csv" do
        column :a
        column :b, label: "Badgers"
        column :c
        column :sum do |record|
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
      "Content-Disposition" => %(attachment; filename="test.csv")
    })
  end
end
