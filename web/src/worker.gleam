import gleam/int
import gleam/json
import gleam/list

pub type Mutation {
  Mutation(id: String, payload: String, created_at: Int)
}

/// Gleam values are immutable, so both network lanes receive the same ordered
/// snapshot and a retry cannot silently rewrite the batch.
pub fn encode_retry_snapshot(batch: List(Mutation)) -> String {
  batch
  |> list.sort(fn(left, right) {
    int.compare(left.created_at, right.created_at)
  })
  |> json.array(fn(mutation) {
    json.object([
      #("id", json.string(mutation.id)),
      #("payload", json.string(mutation.payload)),
      #("createdAt", json.int(mutation.created_at)),
    ])
  })
  |> json.to_string
}

pub fn multiplex_payloads(batch: List(Mutation)) -> #(String, String) {
  let frozen = encode_retry_snapshot(batch)
  #(frozen, frozen)
}
