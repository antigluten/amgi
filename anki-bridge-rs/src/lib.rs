//! C ABI bridge for the Anki Rust backend.
//!
//! Exposes functions matching the pattern used by AnkiDroid's JNI bridge,
//! adapted for C ABI (Swift interop via XCFramework).

use std::os::raw::c_int;
use std::slice;

use anki::backend::{init_backend, Backend};

/// Create a new Anki backend instance.
///
/// # Safety
/// - `init_data` must point to a valid buffer of `init_len` bytes containing
///   a serialized `BackendInit` protobuf message (or be null for defaults).
/// - `out_ptr` must point to writable memory for a single i64.
///
/// Returns 0 on success, -1 on error.
#[no_mangle]
pub unsafe extern "C" fn anki_open_backend(
    init_data: *const u8,
    init_len: usize,
    out_ptr: *mut i64,
) -> c_int {
    let init_bytes: &[u8] = if init_data.is_null() || init_len == 0 {
        // Empty init → default BackendInit (empty preferred_langs, server=false)
        b""
    } else {
        unsafe { slice::from_raw_parts(init_data, init_len) }
    };

    // If empty bytes, encode a default BackendInit
    let effective_bytes: Vec<u8>;
    let bytes_to_use = if init_bytes.is_empty() {
        use prost::Message;
        let default_init = anki_proto::backend::BackendInit::default();
        effective_bytes = default_init.encode_to_vec();
        &effective_bytes
    } else {
        init_bytes
    };

    match init_backend(bytes_to_use) {
        Ok(backend) => {
            let boxed = Box::new(backend);
            let ptr = Box::into_raw(boxed) as i64;
            unsafe { *out_ptr = ptr };
            0
        }
        Err(_e) => -1,
    }
}

/// Execute a backend RPC method via protobuf.
///
/// # Safety
/// - `backend_ptr` must be a valid pointer returned by `anki_open_backend`.
/// - `input_data`/`input_len` must describe a valid protobuf request.
/// - `out_data`/`out_len` receive the response (caller frees with `anki_free_response`).
///
/// Returns 0 on success (out_data has the response protobuf),
///         1 on backend error (out_data has the error protobuf),
///        -1 on FFI error.
#[no_mangle]
pub unsafe extern "C" fn anki_run_method(
    backend_ptr: i64,
    service: u32,
    method: u32,
    input_data: *const u8,
    input_len: usize,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> c_int {
    let backend = unsafe { &*(backend_ptr as *const Backend) };

    let input = if input_data.is_null() || input_len == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(input_data, input_len) }
    };

    match backend.run_service_method(service, method, input) {
        Ok(output) => {
            set_output(output, out_data, out_len);
            0 // success
        }
        Err(err_bytes) => {
            set_output(err_bytes, out_data, out_len);
            1 // backend error (response contains error protobuf)
        }
    }
}

/// Free a response buffer allocated by `anki_run_method`.
#[no_mangle]
pub unsafe extern "C" fn anki_free_response(data: *mut u8, len: usize) {
    if !data.is_null() && len > 0 {
        let _ = unsafe { Vec::from_raw_parts(data, len, len) };
    }
}

/// Close and destroy the backend instance.
#[no_mangle]
pub unsafe extern "C" fn anki_close_backend(backend_ptr: i64) {
    if backend_ptr != 0 {
        let _ = unsafe { Box::from_raw(backend_ptr as *mut Backend) };
    }
}

// -- Helpers --

unsafe fn set_output(data: Vec<u8>, out_data: *mut *mut u8, out_len: *mut usize) {
    let len = data.len();
    if len > 0 {
        let mut boxed = data.into_boxed_slice();
        let ptr = boxed.as_mut_ptr();
        std::mem::forget(boxed);
        unsafe {
            *out_data = ptr;
            *out_len = len;
        }
    } else {
        unsafe {
            *out_data = std::ptr::null_mut();
            *out_len = 0;
        }
    }
}
