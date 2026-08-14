import gleeunit
import gleeunit/should
import worker

pub fn main() {
  gleeunit.main()
}

pub fn multiplex_lanes_share_one_ordered_immutable_body_test() {
  let batch = [
    worker.Mutation("m-2", "two", 2),
    worker.Mutation("m-1", "one", 1),
  ]

  let #(upload, realtime) = worker.multiplex_payloads(batch)

  upload |> should.equal(realtime)
  upload
  |> should.equal(
    "[{\"id\":\"m-1\",\"payload\":\"one\",\"createdAt\":1},{\"id\":\"m-2\",\"payload\":\"two\",\"createdAt\":2}]",
  )
}
