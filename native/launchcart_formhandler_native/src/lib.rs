use rustler::NifResult;
use rustler::ResourceArc;
use std::sync::Mutex;
use wasm_components_ex::component::ComponentResource;
use wasm_components_ex::store::{ComponentStoreData, ComponentStoreResource};
use wasmtime::component::{bindgen, Linker};
use wasmtime::{Config, Engine, Store};

bindgen!("form-handler" in "form-handler.wit");

pub struct FormHandlerResource {
    pub inner: Mutex<FormHandler>,
}

#[rustler::resource_impl()]
impl rustler::Resource for FormHandlerResource {}

fn build_linker(store: &mut Store<ComponentStoreData>) -> Linker<ComponentStoreData> {
    let mut linker = Linker::new(store.engine());
    wasmtime_wasi::add_to_linker_sync(&mut linker);
    wasmtime_wasi_http::add_only_http_to_linker_sync(&mut linker);
    linker
}

#[rustler::nif(name = "instantiate")]
pub fn instantiate(
    component_store_resource: ResourceArc<ComponentStoreResource>,
    component_resource: ResourceArc<ComponentResource>,
) -> NifResult<ResourceArc<FormHandlerResource>> {
    let component_store: &mut Store<ComponentStoreData> =
        &mut *(component_store_resource.inner.lock().map_err(|e| {
            rustler::Error::Term(Box::new(format!(
                "Could not unlock component_store resource as the mutex was poisoned: {e}"
            )))
        })?);

    let component = &mut component_resource.inner.lock().map_err(|e| {
        rustler::Error::Term(Box::new(format!(
            "Could not unlock component resource as the mutex was poisoned: {e}"
        )))
    })?;

    let linker = build_linker(component_store);
    let form_handler_instance = FormHandler::instantiate(component_store, &component, &linker)
        .map_err(|err| rustler::Error::Term(Box::new(err.to_string())))?;

    Ok(ResourceArc::new(FormHandlerResource {
        inner: Mutex::new(form_handler_instance),
    }))
}

#[rustler::nif(name = "handle_submit")]
pub fn handle_submit(
    store_or_caller_resource: ResourceArc<ComponentStoreResource>,
    form_handler_resource: ResourceArc<FormHandlerResource>,
    form_values: Vec<FormValue>
) -> NifResult<String> {
    let store_or_caller: &mut Store<ComponentStoreData> =
        &mut *(store_or_caller_resource.inner.lock().map_err(|e| {
            rustler::Error::Term(Box::new(format!(
                "Couldn't unlock store_or_caller resource as the mutex was poisoned: {e}"
            )))
        })?);

    let form_handler = &mut form_handler_resource.inner.lock().map_err(|e| {
        rustler::Error::Term(Box::new(format!(
            "Could not unlock todo_list resource as the mutex was poisoned: {e}"
        )))
    })?;

    form_handler
        .call_handle_submit(store_or_caller, &form_values)
        .map_err(|err| rustler::Error::Term(Box::new(err.to_string())))
}

rustler::init!("Elixir.LaunchCart.Forms.WasmComponentHandler.Native");
