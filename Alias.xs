#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"
#include "ptr_table.h"

#ifndef SvPAD_TYPED
#define SvPAD_TYPED(sv) (SvFLAGS(sv) & SVpad_TYPED)
#endif

#ifndef gv_stashpvs
#define gv_stashpvs(s, add) Perl_gv_stashpvn(aTHX_ STR_WITH_LEN(s), add)
#endif

#define PACKAGE "Scalar::Alias"

#define MY_CXT_KEY PACKAGE "::_guts" XS_VERSION
typedef struct{
	HV* alias_stash;

	peep_t old_peepp;

	PTR_TBL_t* seen;
} my_cxt_t;
START_MY_CXT


static OP*
sa_pp_alias(pTHX){
	dVAR; dSP;
	dTOPss;                              /* right-hand side value */
	PADOFFSET const po = PL_op->op_targ; /* left-hand side variable (padoffset) */

	if(SvTEMP(sv)){
		SAVEGENERICSV(PAD_SVl(po));

		SvREFCNT_inc_simple_void_NN(sv);
	}
	else{
		SAVESPTR(PAD_SVl(po));
	}

	PAD_SVl(po) = sv;

	SETs(sv);
	RETURN;
}

static int
sa_check_alias_assign(pTHX_ pMY_CXT_ const OP* const o){
	dVAR;
	OP* const kid = cBINOPo->op_last;

	assert(o->op_flags & OPf_KIDS);

	if(!(o->op_private & OPpASSIGN_BACKWARDS) /* not orassign, andassign nor dorassign */
		&& kid
		&& kid->op_type == OP_PADSV
		&& kid->op_private & OPpLVAL_INTRO
		&& o->op_targ == 0 /* it will be nil, but other similar mecanism can set non-zero */
	){

		SV* const padname = AvARRAY(PL_comppad_name)[kid->op_targ];

		assert(AvMAX(PL_comppad_name) >= (I32)kid->op_targ);

		if(SvPAD_TYPED(padname)
			&& SvSTASH(padname) == MY_CXT.alias_stash){ /* my alias $foo = ... */

			return TRUE;
		}
	}

	return FALSE;
}

static void
sa_die(pTHX_ pMY_CXT_ COP* const cop, SV* const padname, const char* const msg){
	dVAR;

	ENTER;
	SAVEVPTR(PL_curcop);
	PL_curcop = cop;

	ptr_table_free(MY_CXT.seen);
	MY_CXT.seen = NULL;

	Perl_croak(aTHX_ "Cannot declare my alias %s %s", SvPVX_const(padname), msg);
	LEAVE; /* not reached */
}

static void
sa_inject(pTHX_ pMY_CXT_ COP* cop, OP* o){
	dVAR;
	COP* const oldcop = cop;

	assert(MY_CXT.seen != NULL);

	for(; o; o = o->op_next){
		if(ptr_table_fetch(MY_CXT.seen, o)){
			break;
		}
		ptr_table_store(MY_CXT.seen, o, (void*)TRUE);

		switch(o->op_type){
		case OP_SASSIGN:
		if(sa_check_alias_assign(aTHX_ aMY_CXT_ o)){
			OP* const rhs = cBINOPo->op_first;
			OP* const lhs = cBINOPo->op_last;

			/* move the target sv (reference to my variable) */
			o->op_targ   = lhs->op_targ;
			lhs->op_targ = 0;

			o->op_type   = OP_CUSTOM;
			o->op_ppaddr = sa_pp_alias;

			op_null(lhs);

			/* The right-hand side OP can be lvalue */
			rhs->op_flags |= OPf_MOD;

			if(rhs->op_type == OP_AELEM || rhs->op_type == OP_HELEM){
				rhs->op_private |= OPpLVAL_DEFER;
			}

			break;
		}
		case OP_PADSV:{
			SV* const padname = AvARRAY(PL_comppad_name)[o->op_targ];

			if(SvPAD_TYPED(padname) && SvSTASH(padname) == MY_CXT.alias_stash && o->op_private & OPpLVAL_INTRO){
				if(o->op_private & OPpDEREF){
					sa_die(aTHX_ aMY_CXT_ cop, padname, "with dereference");
					return;
				}
				else if(o->op_next->op_type != OP_SASSIGN){
					return sa_die(aTHX_ aMY_CXT_ cop, padname, "without assignment");
					return;
				}
			}
			break;
		}

		/* we concerned with only OP_SASSIGN and OP_PADSV, but should check all the opcode tree */
		case OP_NEXTSTATE:
		case OP_DBSTATE:
			cop = ((COP*)o); /* for context info */
			break;

		case OP_MAPWHILE:
		case OP_GREPWHILE:
		case OP_AND:
		case OP_OR:
#ifdef pp_dor
		case OP_DOR:
#endif
		case OP_ANDASSIGN:
		case OP_ORASSIGN:
#ifdef pp_dorassign
		case OP_DORASSIGN:
#endif
		case OP_COND_EXPR:
		case OP_RANGE:
#ifdef pp_once
		case OP_ONCE:
#endif
			sa_inject(aTHX_ aMY_CXT_ cop, cLOGOPo->op_other);
			break;
		case OP_ENTERLOOP:
		case OP_ENTERITER:
			sa_inject(aTHX_ aMY_CXT_ cop, cLOOPo->op_redoop);
			sa_inject(aTHX_ aMY_CXT_ cop, cLOOPo->op_nextop);
			sa_inject(aTHX_ aMY_CXT_ cop, cLOOPo->op_lastop);
			break;
		case OP_SUBST:
#if PERL_BCDVERSION >= 0x5010000
			sa_inject(aTHX_ aMY_CXT_ cop, cPMOPo->op_pmstashstartu.op_pmreplstart);
#else
			sa_inject(aTHX_ aMY_CXT_ cop, cPMOPo->op_pmreplstart);
#endif
			break;

		default:
			NOOP;
		}
	}

	cop = oldcop;
}

static int
sa_enabled(pTHX){
	dVAR;
	SV** svp = AvARRAY(PL_comppad_name);
	SV** end = svp + AvFILLp(PL_comppad_name) + 1;

	while(svp != end){
		if(SvPAD_TYPED(*svp)){
			return TRUE;
		}

		svp++;
	}

	return FALSE;
}

static void
sa_peep(pTHX_ OP* const o){
	dVAR;
	dMY_CXT;

	assert(o);

	if(sa_enabled(aTHX)){
		assert(MY_CXT.seen == NULL);
		MY_CXT.seen = ptr_table_new();

		sa_inject(aTHX_ aMY_CXT_ PL_curcop, o);

		ptr_table_free(MY_CXT.seen);
		MY_CXT.seen = NULL;
	}

	MY_CXT.old_peepp(aTHX_ o);
}


static void
sa_setup_opnames(pTHX){
	dVAR;
	SV* const keysv = newSViv(PTR2IV(sa_pp_alias));

	if(!PL_custom_op_names){
		PL_custom_op_names = newHV();
	}
	if(!PL_custom_op_descs){
		PL_custom_op_descs = newHV();
	}

	hv_store_ent(PL_custom_op_names, keysv, newSVpvs("alias"),        0U);
	hv_store_ent(PL_custom_op_descs, keysv, newSVpvs("scalar alias"), 0U);

	SvREFCNT_dec(keysv);
}


MODULE = Scalar::Alias	PACKAGE = Scalar::Alias

PROTOTYPES: DISABLE

BOOT:
{
	MY_CXT_INIT;

	MY_CXT.alias_stash   = gv_stashpvs("alias", GV_ADD);

	MY_CXT.old_peepp     = PL_peepp;
	PL_peepp             = sa_peep;

	sa_setup_opnames(aTHX);
}


#ifdef USE_ITHREADS

void
CLONE(...)
CODE:
{
	MY_CXT_CLONE;
	MY_CXT.alias_stash = gv_stashpvs("alias", GV_ADD);
	PERL_UNUSED_VAR(items);
}

#endif
