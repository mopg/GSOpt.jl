"""
    Abstract types for geometric programming.

Base types for the geometric programming extension.
Defined separately to avoid circular dependencies.
"""

"""
    AbstractGPVariable <: JuMP.AbstractVariableRef

Abstract type for variables in geometric programming models.
Extends JuMP's AbstractVariableRef to ensure compatibility with JuMP's interface.
"""
abstract type AbstractGPVariable <: JuMP.AbstractVariableRef end

"""
    AbstractGPExpression <: JuMP.AbstractJuMPScalar

Abstract type for expressions in geometric programming models.
Extends JuMP's AbstractJuMPScalar to ensure compatibility with JuMP's interface.
Subtypes include MonomialExpression, PosynomialExpression, and SignomialExpression.
"""
abstract type AbstractGPExpression <: JuMP.AbstractJuMPScalar end
