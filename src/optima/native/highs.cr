module Optima
  @[Link("highs")]
  lib LibHighs
    alias HighsInt = LibC::Int

    # Variable types (integrality)
    # kHighsVarTypeContinuous = 0
    # kHighsVarTypeInteger = 1
    # kHighsVarTypeSemiContinuous = 2

    # Objective sense
    # kHighsObjSenseMinimize = 1
    # kHighsObjSenseMaximize = -1

    # HighsStatus
    # kHighsStatusOk = 0
    # kHighsStatusWarning = 1
    # kHighsStatusError = -1

    # Model status (see /usr/include/highs/interfaces/highs_c_api.h)
    # kNotset = 0
    # kLoadError = 1
    # kModelError = 2
    # kPresolveError = 3
    # kSolveError = 4
    # kPostsolveError = 5
    # kModelEmpty = 6
    # kOptimal = 7
    # kInfeasible = 8
    # kUnboundedOrInfeasible = 9
    # kUnbounded = 10
    # kObjectiveBound = 11
    # kObjectiveTarget = 12
    # kTimeLimit = 13
    # kIterationLimit = 14
    # kUnknown = 15
    # kSolutionLimit = 16
    # kInterrupt = 17

    # Basis status
    # kLower = 0
    # kBasic = 1
    # kUpper = 2
    # kZero = 3
    # kNonbasic = 4

    fun Highs_create : Void*
    fun Highs_destroy(highs : Void*) : Void

    fun Highs_addCol(highs : Void*, cost : LibC::Double, lower : LibC::Double, upper : LibC::Double, num_new_nz : HighsInt, index : HighsInt*, value : LibC::Double*) : HighsInt
    fun Highs_addRow(highs : Void*, lower : LibC::Double, upper : LibC::Double, num_new_nz : HighsInt, index : HighsInt*, value : LibC::Double*) : HighsInt

    fun Highs_changeObjectiveSense(highs : Void*, sense : HighsInt) : HighsInt
    fun Highs_changeColIntegrality(highs : Void*, col : HighsInt, integrality : HighsInt) : HighsInt
    fun Highs_run(highs : Void*) : HighsInt
    fun Highs_setBoolOptionValue(highs : Void*, option : LibC::Char*, value : HighsInt) : HighsInt
    fun Highs_setIntOptionValue(highs : Void*, option : LibC::Char*, value : HighsInt) : HighsInt
    fun Highs_setDoubleOptionValue(highs : Void*, option : LibC::Char*, value : LibC::Double) : HighsInt
    fun Highs_setStringOptionValue(highs : Void*, option : LibC::Char*, value : LibC::Char*) : HighsInt
    fun Highs_readModel(highs : Void*, filename : LibC::Char*) : HighsInt
    fun Highs_writeModel(highs : Void*, filename : LibC::Char*) : HighsInt
    fun Highs_setSolution(highs : Void*, col_value : LibC::Double*, col_dual : LibC::Double*, row_value : LibC::Double*, row_dual : LibC::Double*) : HighsInt
    fun Highs_passHessian(highs : Void*, dim : HighsInt, num_nz : HighsInt, format : HighsInt, start : HighsInt*, index : HighsInt*, value : LibC::Double*) : HighsInt

    fun Highs_getSolution(highs : Void*, col_value : LibC::Double*, col_dual : LibC::Double*, row_value : LibC::Double*, row_dual : LibC::Double*) : HighsInt
    fun Highs_getObjectiveValue(highs : Void*) : LibC::Double
    fun Highs_getModelStatus(highs : Void*) : HighsInt
    fun Highs_getIntInfoValue(highs : Void*, info : LibC::Char*, value : HighsInt*) : HighsInt
    fun Highs_getDoubleInfoValue(highs : Void*, info : LibC::Char*, value : LibC::Double*) : HighsInt

    # Basis-based warm start: col/row_status arrays use the `kHighsBasisStatus*` codes above.
    fun Highs_getBasis(highs : Void*, col_status : HighsInt*, row_status : HighsInt*) : HighsInt
    fun Highs_setBasis(highs : Void*, col_status : HighsInt*, row_status : HighsInt*) : HighsInt

    # Native ranging (sensitivity) analysis - exact, single-solve alternative to
    # perturb-and-resolve. Every output array must be sized to num_col, except the
    # two row_bound_* pairs which are sized to num_row.
    fun Highs_getRanging(
      highs : Void*,
      col_cost_up_value : LibC::Double*, col_cost_up_objective : LibC::Double*,
      col_cost_up_in_var : HighsInt*, col_cost_up_ou_var : HighsInt*,
      col_cost_dn_value : LibC::Double*, col_cost_dn_objective : LibC::Double*,
      col_cost_dn_in_var : HighsInt*, col_cost_dn_ou_var : HighsInt*,
      col_bound_up_value : LibC::Double*, col_bound_up_objective : LibC::Double*,
      col_bound_up_in_var : HighsInt*, col_bound_up_ou_var : HighsInt*,
      col_bound_dn_value : LibC::Double*, col_bound_dn_objective : LibC::Double*,
      col_bound_dn_in_var : HighsInt*, col_bound_dn_ou_var : HighsInt*,
      row_bound_up_value : LibC::Double*, row_bound_up_objective : LibC::Double*,
      row_bound_up_in_var : HighsInt*, row_bound_up_ou_var : HighsInt*,
      row_bound_dn_value : LibC::Double*, row_bound_dn_objective : LibC::Double*,
      row_bound_dn_in_var : HighsInt*, row_bound_dn_ou_var : HighsInt*,
    ) : HighsInt

    fun Highs_setCallback(highs : Void*, callback : (LibC::Int, LibC::Char*, Void*, Void*, Void* -> Void), user_data : Void*) : HighsInt
    fun Highs_startCallback(highs : Void*, callback_type : HighsInt) : HighsInt
    fun Highs_stopCallback(highs : Void*, callback_type : HighsInt) : HighsInt
  end
end
