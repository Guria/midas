//// Functions for working with HTTP data structures in Gleam.
////
//// This module makes it easy to create and modify Requests and Responses, data types.
//// A general HTTP message type is defined that enables functions to work on both requests and responses.
////
//// This module does not implement a HTTP client or HTTP server, but it can be as a base for them.

import gleam/int
import gleam/iodata.{Iodata}
import gleam/list
import gleam/option.{Option, Some, None}
import gleam/string
import gleam/uri

/// HTTP standard method as defined by [RFC 2616](https://tools.ietf.org/html/rfc2616),
/// and PATCH which is defined by [RFC 5789](https://tools.ietf.org/html/rfc5789).
pub type Method {
  Get
  Post
  Head
  Put
  Delete
  Trace
  Connect
  Options
  Patch
}

/// Data type containing an attribute value pair that constitute an HTTP header.
pub type Header =
  tuple(String, String)

/// A general data type that can be be parameterised as a `Request` or `Response`
pub type Message(head, body) {
  Message(head: head, headers: List(Header), body: body)
}

/// Data structure containing the deserialized components of an HTTP request start line.
pub type RequestHead {
  RequestHead(
    method: Method,
    host: String,
    port: Option(Int),
    path: String,
    query: Option(String),
  )
}

/// Data structure containing the deserialized components of an HTTP response status line.
pub type ResponseHead {
  ResponseHead(status: Int)
}

/// HTTP message type parameterised as a Request.
pub type Request(body) =
  Message(RequestHead, body)

/// HTTP message type parameterised as a Response.
pub type Response(body) =
  Message(ResponseHead, body)

/// Construct a `Request` type.
///
/// The provided `uri_string` should be an absolure uri, including the scheme and host.
/// The body type of the returned request is `Nil`,
/// and should be set with a call to `set_body`.
pub fn request(method: Method, uri_string: String) -> Request(Nil) {
  let Ok(
    uri.Uri(host: Some(host), port: port, path: path, query: query, ..),
  ) = uri.parse(uri_string)
  Message(
    head: RequestHead(method, host, port, path, query),
    headers: [],
    body: Nil,
  )
}

/// Construct a `Response` type.
///
/// The body type of the returned response is `Nil`,
/// and should be set with a call to `set_body`.
pub fn response(status: Int) -> Response(Nil) {
  Message(head: ResponseHead(status), headers: [], body: Nil)
}

/// Get the method of a request.
pub fn method(message: Message(RequestHead, body)) -> Method {
  let Message(RequestHead(method: method, ..), ..) = message
  method
}

/// Get the host of a request.
pub fn host(message: Message(RequestHead, body)) -> String {
  let Message(RequestHead(host: host, ..), ..) = message
  host
}

/// Get the port of a request, if one was explicitly given.
pub fn port(message: Message(RequestHead, body)) -> Option(Int) {
  let Message(RequestHead(port: port, ..), ..) = message
  port
}

/// Return the none-empty segments of a request path.
pub fn path_segments(message: Message(RequestHead, body)) -> List(String) {
  let Message(RequestHead(path: path, ..), ..) = message
  uri.path_segments(path)
}

/// Decode the query from a request.
pub fn get_query(
  message: Message(RequestHead, body),
) -> Result(List(tuple(String, String)), Nil) {
  let Message(RequestHead(query: query_string, ..), ..) = message
  case query_string {
    Some(query_string) -> uri.parse_query(query_string)
    None -> Ok([])
  }
}

/// Get the value associated with a header field, if one was set.
pub fn get_header(message: Message(head, body), key: String) -> Option(String) {
  let Message(headers: headers, ..) = message
  list.key_find(headers, string.lowercase(key))
  |> option.from_result()
}

/// Set the value of a header field.
pub fn set_header(
  message: Message(head, body),
  key: String,
  value: String,
) -> Message(head, body) {
  let Message(head: head, headers: headers, body: body) = message
  let headers = list.append(headers, [tuple(string.lowercase(key), value)])
  Message(head: head, headers: headers, body: body)
}

/// Fetch the HTTP body as a string.
///
/// This method returns the body as a `String` for simplicity.
/// Internally the body of HTTP messages is represented as `Iodata`.
pub fn get_body(message: Message(head, Iodata)) -> String {
  let Message(body: body, ..) = message
  iodata.to_string(body)
}

/// Add the body to a HTTP message.
pub fn set_body(
  message: Message(head, Nil),
  body: String,
) -> Message(head, Iodata) {
  let Message(head: head, headers: headers, body: _nil) = message
  let body = iodata.from_strings([body])
  let content_length = iodata.byte_size(body)
  let headers = list.append(
    headers,
    [tuple("content-length", int.to_string(content_length))],
  )
  Message(head: head, headers: headers, body: body)
}

/// Fetch the body content decoded as a form.
pub fn get_form(
  message: Message(head, Iodata),
) -> Result(List(tuple(String, String)), Nil) {
  let Message(body: body, ..) = message
  uri.parse_query(iodata.to_string(body))
}

/// Set the body serialized as a form.
pub fn set_form(message, form) {
  message
  |> set_header("content-type", "application/x-www-form-urlencoded")
  |> set_body(uri.query_to_string(form))
}

/// Create a response that redirects to the given uri.
pub fn redirect(uri: String) -> Response(Iodata) {
  response(303)
  |> set_header("location", uri)
  |> set_body("")
}
