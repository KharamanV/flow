(**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)
(** Intermediate representation for functions *)

type kind =
  | Ordinary
  | Async
  | Generator
  | AsyncGenerator
  | FieldInit of (ALoc.t, ALoc.t) Flow_ast.Expression.t
  | Predicate
  | Ctor

type t = {
  reason: Reason.t;
  kind: kind;
  tparams: Type.typeparams;
  tparams_map: Type.t SMap.t;
  fparams: Func_params.t;
  body: (ALoc.t, ALoc.t) Flow_ast.Function.body option;
  return_t: Type.t;
}

(** 1. Constructors *)

(** Create signature for a default constructor.

    Flow represents default constructors as empty functions, i.e., functions
    with no type parameters, no formal parameters, an empty body, and a void
    return type. *)
val default_constructor:
  Reason.t ->
  t

(** Create signature for a class field initializer.

    Field initializers are evaluated in the context of the class body.
    Representing the initializer as a function means we can reuse `toplevels`
    from this module to evaluate the initializer in the appropriate context,
    where `this` and `super` point to the appropriate types. *)
val field_initializer:
  Type.t SMap.t -> (* type params map *)
  Reason.t ->
  (ALoc.t, ALoc.t) Flow_ast.Expression.t -> (* init *)
  Type.t -> (* return *)
  t

(** 1. Manipulation *)

(** Return a signature with types from provided map substituted.

    Note that this function does not substitute type parameters declared by the
    function itself, which may shadow the names of type parameters in the
    provided map.

    This signature's own type parameters will be subtituted by the
    `generate-tests` function. *)
val subst: Context.t ->
  Type.t SMap.t -> (* type params map *)
  t -> t

(** Invoke callback with type parameters substituted by upper/lower bounds. *)
val generate_tests: Context.t ->
  (t -> 'a) -> t -> 'a

(** Evaluate the function.

    This function creates a new scope, installs bindings for the function's
    parameters and internal bindings (e.g., this, yield), processes the
    statements in the function body, and provides an implicit return type if
    necessary. This is when the body of the function gets checked, so it also
    returns a typed AST of the function body. *)
val toplevels:
  ALoc.t Flow_ast.Identifier.t option -> (* id *)
  Context.t ->
  Scope.Entry.t -> (* this *)
  Scope.Entry.t -> (* super *)
  decls:(Context.t -> (ALoc.t, ALoc.t) Flow_ast.Statement.t list -> unit) ->
  stmts:(Context.t -> (ALoc.t, ALoc.t) Flow_ast.Statement.t list ->
                      (ALoc.t, ALoc.t * Type.t) Flow_ast.Statement.t list) ->
  expr:(Context.t -> (ALoc.t, ALoc.t) Flow_ast.Expression.t ->
                      (ALoc.t, ALoc.t * Type.t) Flow_ast.Expression.t) ->
  t ->
  (ALoc.t, ALoc.t * Type.t) Flow_ast.Function.body option *
  (ALoc.t, ALoc.t * Type.t) Flow_ast.Expression.t option

(** 1. Type Conversion *)

(** Create a function type for function declarations/expressions. *)
val functiontype: Context.t ->
  Type.t -> (* this *)
  t -> Type.t

(** Create a function type for class/interface methods. *)
val methodtype: Context.t -> t -> Type.t

(** Create a type of the return expression of a getter function.

    Note that this is a partial function. If the signature does not represent a
    getter, this function will raise an exception. *)
val gettertype: t -> Type.t

(** Create a type of the single parameter of a setter function.

    Note that this is a partial function. If the signature does not represent a
    setter, this function will raise an exception. *)
val settertype: t -> Type.t

(** 1. Util *)

(** The location of the return type for a function. *)
val return_loc: (ALoc.t, ALoc.t) Flow_ast.Function.t -> ALoc.t
val to_ctor_sig: t -> t

val with_typeparams: Context.t -> (unit -> 'a) -> t -> 'a
