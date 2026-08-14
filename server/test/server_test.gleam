import gleam/string
import gleeunit
import gleeunit/should
import server

pub fn main() {
  gleeunit.main()
}

pub fn official_client_encodes_immutable_protocol_batch_test() {
  let assert Ok(body) = server.durable_push_body()

  body |> string.contains("\"clientId\":\"gleam-e2e\"") |> should.be_true
  body |> string.contains("\"mutationId\":\"1\"") |> should.be_true
  body |> string.contains("offline Gleam edit") |> should.be_true
}
