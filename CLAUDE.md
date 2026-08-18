# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle exec rspec                       # run the suite (also `rake spec`, the default task)
bundle exec rspec spec/csv_spec.rb:87   # single example by line
bundle exec rspec --only-failures       # uses .rspec_status
bin/console                             # IRB with decisive loaded
```

Rails version matrix via appraisal (CI runs rails 8.0/8.1 × ruby 3.3/3.4/4.0):

```bash
bundle exec appraisal install
bundle exec appraisal rails-8.1 rake
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle exec rspec
```

## Architecture

Decisive is an ActionView template handler for the `.decisive` extension. `Decisive::Rails` (an
engine, only defined when Rails is) registers the handler and the `:xls` mime type.

**The compile step is the center of the design.** `TemplateHandler.call` does not render anything —
it returns a string of Ruby that Rails compiles into the view. That generated code:

1. `extend Decisive::DSL` on the view, then evaluates the *entire template source as one expression*
   whose value is a **context object**;
2. sets `Content-Disposition` / `Content-Type` / `Content-Transfer-Encoding` from that context;
3. either pumps `context.each` into `response.stream`, or returns `context.to_csv` / `context.to_xls`.

So the generated code references `response`, `controller`, and `@stream` as bare names in the view's
scope. Anything that changes headers or the stream/buffer decision lives in the heredoc in
`template_handler.rb`, not in the contexts.

`DSL#csv` / `DSL#xls` pick one of three contexts:

| Context | When | Behavior |
| --- | --- | --- |
| `StreamCSVContext` | `csv`, default `stream: true` | Columns are collected once at template-eval time, so headers are fixed up front. Raises unless the controller `is_a?(ActionController::Live)`, and unless the block has arity 0. |
| `RenderCSVContext` | `csv ..., stream: false` | Buffers everything through `Renderer`. The block is re-run per record, so columns may vary per row. |
| `RenderXLSContext` | `xls` | Worksheets come either from `worksheet` calls inside the block, or from a `{name => records}` hash argument with one shared column block. Renders with RubyXL. |

`Renderer` (used by the two non-streaming contexts) builds a hash per record and takes the **union of
keys in first-seen order** as the header — that is what makes non-deterministic headers work, and it
is why the two pending `xit` specs about repeating column names fail: duplicate labels collapse onto
one key.

**`#column` is implemented twice** — `StreamCSVContext#column` (streaming) and `Renderer::Row#column`
(non-streaming). They must stay behaviorally identical: value resolution is block > `Symbol`
accessor > literal value > accessor inferred from the label (`"Full name".parameterize.underscore`),
and every value is `to_s`'d.

`ViewDelegation` is `method_missing` forwarding to the view, mixed into `Renderer::Row`,
`StreamCSVContext`, and `RenderXLSContext`. It is why template blocks can call view helpers even
though they are `instance_exec`'d against decisive's objects. Instance variables deliberately do
*not* follow — they belong to the view — so blocks see `nil` for `@foo`. It also scrubs its own
frames from `NameError` backtraces to keep the template's line on top; a spec asserts on that.

XLS specifics in `RenderXLSContext`: sheet names are sanitized (illegal chars → spaces, stripped of
surrounding quotes, truncated to 31 chars), and cells are always written as **data, never formulas**
— a leading `=` is intentionally literal (see commit 3bdd657). Do not reintroduce formula detection.

## Testing conventions

Specs never boot Rails. Each example fakes a template with `Struct.new(:source)`, then
`eval(Decisive::TemplateHandler.call(template))` — meaning the RSpec example itself plays the role of
the view. Consequences worth knowing before writing a spec:

- `response` and `controller` are `let` doubles; `@records` / `@worksheets` are ivars set in the example.
- Methods defined on the example group (`shout`, `whisper`) are the "view helpers" that
  `ViewDelegation` finds — including private ones.
- Streaming examples assert with `expect(response.stream).to receive(:write).with(...)`, in order.
- `ActionController::Live` is `stub_const`'d to a bare module, with `controller.is_a?` stubbed.
- XLS examples write to `tmp/` and read back through `Decisive::XLSHasher`, which is public API for
  downstream test suites, not just an internal helper.
