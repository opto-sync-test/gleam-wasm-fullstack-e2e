import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData}
import opto_sync_client

const shell = "<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width'><title>OptoSync Gleam WASM</title></head><body><main><h1>Gleam + WebAssembly OptoSync</h1><p>Durable browser queue and concurrent BEAM workers.</p></main><script type='module' src='/worker-bootstrap.mjs'></script></body></html>"

pub fn durable_push_body() -> Result(String, opto_sync_client.ProtocolError) {
  use queue <- result.try(opto_sync_client.new("gleam-e2e"))
  use #(queued, _) <- result.try(opto_sync_client.enqueue_upsert(
    queue,
    "documents",
    "gleam-1",
    "{\"title\":\"offline Gleam edit\"}",
    None,
    False,
  ))
  use request <- result.try(opto_sync_client.build_push_request(queued, 100))
  Ok(opto_sync_client.encode_push_request(request))
}

fn text(
  status: Int,
  content_type: String,
  body: String,
) -> Response(ResponseData) {
  response.new(status)
  |> response.prepend_header("content-type", content_type)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

fn static_file(path: String, content_type: String) -> Response(ResponseData) {
  mist.send_file(path, offset: 0, limit: None)
  |> result.map(fn(file) {
    response.new(200)
    |> response.prepend_header("content-type", content_type)
    |> response.set_body(file)
  })
  |> result.lazy_unwrap(fn() {
    text(404, "application/json", "{\"error\":\"asset not found\"}")
  })
}

fn static_tree(
  prefix: String,
  segments: List(String),
) -> Response(ResponseData) {
  let safe =
    list.all(segments, fn(segment) {
      segment != ""
      && !string.contains(segment, "..")
      && !string.contains(segment, "/")
    })
  case safe {
    True ->
      static_file(
        prefix <> "/" <> string.join(segments, "/"),
        "application/javascript",
      )
    False -> text(400, "application/json", "{\"error\":\"invalid asset path\"}")
  }
}

pub fn handle(request: Request(Connection)) -> Response(ResponseData) {
  case request.path_segments(request) {
    [] -> text(200, "text/html; charset=utf-8", shell)
    ["service-worker.js"] ->
      static_file("../web/public/service-worker.js", "application/javascript")
    ["worker-bootstrap.mjs"] ->
      static_file(
        "../web/public/worker-bootstrap.mjs",
        "application/javascript",
      )
    ["gleam", ..segments] ->
      static_tree("../web/build/dev/javascript", segments)
    ["wasm", ..segments] ->
      static_tree(
        "../vendor/opto-sync-clients/syncer.c/bindings/wasm",
        segments,
      )
    ["api", "sync", lane] if lane == "upload" || lane == "realtime" ->
      text(
        200,
        "application/json",
        "{\"lane\":\"" <> lane <> "\",\"accepted\":true}",
      )
    _ -> text(404, "application/json", "{\"error\":\"not found\"}")
  }
}

pub fn main() {
  let assert Ok(_) =
    handle
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(4000)
    |> mist.start

  process.sleep_forever()
}
