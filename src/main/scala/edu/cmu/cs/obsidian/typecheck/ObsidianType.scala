package edu.cmu.cs.obsidian.typecheck
import edu.cmu.cs.obsidian.parser._

sealed abstract class TypeModifier() extends HasLocation
case class IsReadOnlyState() extends TypeModifier {
    override def toString: String = "readonlyState"
}

case class IsRemote() extends TypeModifier {
    override def toString: String = "remote"
}

case class IsOwned() extends TypeModifier {
    override def toString: String = "owned"
}

trait Permission
case class Shared() extends Permission
case class Owned() extends Permission
case class Unowned() extends Permission
case class Inferred() extends Permission // For local variables

// Type of references to contracts.
case class ContractReferenceType(contractType: ContractType, permission: Permission) extends NonPrimitiveType {
    override def toString: String = contractName

    val contractName: String = contractType.contractName

    override def isOwned = permission == Owned()

    override val residualType: NonPrimitiveType = {
        if (permission == Owned()) {
            this.copy(permission = Unowned()).setLoc(this)
        }
        else {
            this
        }
    }
}



// Type of actual contracts. This is ALMOST NEVER the right class; it is specially for actual contracts.
// Almost everywhere will use ContractReferenceType. This intentionally does not extend ObsidianType
// because it is not available in the language itself (for now).
case class ContractType(contractName: String) {
    override def toString: String = contractName
}

/* Invariant: [stateNames] is missing at least one of the states of the
 * contract (i.e. it is more specific than [ContractReferenceType(contractName)],
 * but has at least 2 distinct states
 *
 * StateType is always owned.
 * */
case class StateType(contractName: String, stateNames: Set[String]) extends NonPrimitiveType {
    def this(contractName: String, stateName: String) = {
        this(contractName, Set(stateName))
    }

    private def orOfStates: String = stateNames.toSeq.tail.foldLeft(stateNames.head)(
        (prev: String, sName: String) => prev + " | " + sName
    )
    override def toString: String = contractName + "." + "(" + orOfStates + ")"

    override val permission = Owned()

    override def isOwned = true
}

object StateType {
    def apply(contractName: String, stateName: String): StateType = new StateType(contractName, Set(stateName))
}


/* a path starts with either a local variable or "this", but "this" can sometimes be omitted */
//case class PathType(path: Seq[String], ts: NonPrimitiveType) extends NonPrimitiveType {
//    private def pathAsString = path.foldLeft("")(
//        (prev: String, pathNode: String) => prev + pathNode + "."
//    )
//    override def toString: String = pathAsString + ts.toString
//    override val extractSimpleType: NonPrimitiveType = ts
//}

/* Invariant for permissioned types: any path that occurs in the type makes "this" explicit */
sealed trait ObsidianType extends HasLocation {
    // for tests
    val isBottom: Boolean

    /* the permission system doesn't allow arbitrary aliasing of a reference
     * typed as [t]: aliasing forces one of the resulting types to be
     * [residualType(t)] instead */
    val residualType: ObsidianType

    def isOwned = false
    def isRemote = false

    def isResourceReference(contextContractTable: ContractTable) = false

}

/* int, bool, or string */
sealed trait PrimitiveType extends ObsidianType {
    val isBottom: Boolean = false
    override val residualType: ObsidianType = this
}

/* all permissioned types are associated with their corresponding symbol table
 * These types were generated by resolution; they are not generated by the parser.
 */
sealed trait NonPrimitiveType extends ObsidianType {
    val isBottom: Boolean = false

    val permission: Permission

    val contractName: String


    //    override def toString: String = {
    //        val modifiersString = modifiers.map(m => m.toString).mkString(" ")
    //
    //        if (modifiers.size > 0) {
    //            modifiersString + " " + t.toString
    //        }
    //        else {
    //            t.toString
    //        }
    //    }

    //    override def equals(other: Any): Boolean = {
    //        other match {
    //            case NonPrimitiveType(typ, mod) => typ == t && mod == modifiers
    //            case _ => false
    //        }
    //    }
    //    override def hashCode(): Int = t.hashCode()
    //    val residualType: ObsidianType = if (modifiers.contains(IsOwned()))
    //        NonPrimitiveType(t, modifiers - IsOwned() + IsReadOnlyState())
    //    else this
    val residualType = this

    //override def isRemote = modifiers.contains(IsRemote())

    override def isResourceReference(contextContractTable: ContractTable): Boolean = {
        val contract = contextContractTable.lookupContract(contractName)
        contract.isDefined && contract.get.contract.isResource
    }
}


case class IntType() extends PrimitiveType {
    override def toString: String = "int"
}
case class BoolType() extends PrimitiveType {
    override def toString: String = "bool"
}
case class StringType() extends PrimitiveType {
    override def toString: String = "string"
}
/* Used to indicate an error in the type checker when a reasonable type cannot
 * otherwise be inferred */
case class BottomType() extends ObsidianType {
    val isBottom: Boolean = true
    override val residualType: ObsidianType = this
}

// Only appears before running resolution, which happens right after parsing.
// TODO: remove mods
case class UnresolvedNonprimitiveType(identifiers: Seq[String], mods: Set[TypeModifier], permission: Permission) extends ObsidianType {
    val isBottom: Boolean = false

    override def toString: String = mods.map(m => m.toString).mkString(" ") + " " + identifiers.mkString(".")


    override val residualType: ObsidianType = this // Should never be invoked
}

case class InterfaceContractType(name: String, simpleType: NonPrimitiveType) extends NonPrimitiveType {
    override def toString: String = name
    override val isBottom: Boolean = false
    override val residualType: NonPrimitiveType = this
    override val contractName: String = name
    override val permission: Permission = simpleType.permission
}
