#include "stdlib.h"

struct node {
    struct node *next;
    int value;
};

/*@

inductive list<t> = nil | cons(t, list<t>);

fixpoint list<t> list_add<t>(list<t> xs, t x) {
    switch (xs) {
        case nil: return cons(x, nil);
        case cons(h, t): return cons(h, list_add(t, x));
    }
}

fixpoint list<t> append<t>(list<t> xs, list<t> ys) {
    switch (xs) {
        case nil: return ys;
        case cons(h, t): return cons(h, append(t, ys));
    }
}

lemma void append_nil<t>(list<t> xs)
    requires true;
    ensures append(xs, nil) == xs;
{
    switch (xs) {
        case nil:
        case cons(h, t): append_nil(t);
    }
}

lemma void append_add<t>(list<t> xs, t y, list<t> ys)
    requires true;
    ensures append(list_add(xs, y), ys) == append(xs, cons(y, ys));
{
    switch (xs) {
        case nil:
        case cons(h, t):
            append_add(t, y, ys);
    }
}

fixpoint list<t> tail<t>(list<t> xs) {
    switch (xs) {
        case nil: return nil;
        case cons(h, t): return t;
    }
}

fixpoint int head(list<int> xs) {
    switch (xs) {
        case nil: return 0;
        case cons(h, t): return h;
    }
}

predicate list(struct node *l, list<int> xs) =
    l == 0 ? xs == nil : l->value |-> ?value &*& l->next |-> ?next &*& malloc_block_node(l) &*& list(next, ?tail) &*& xs == cons(value, tail);

@*/

struct node *cons(int value, struct node *next)
    //@ requires list(next, ?tail);
    //@ ensures list(result, cons(value, tail));
{
    struct node *result = malloc(sizeof(struct node));
    if (result == 0) { abort(); }
    result->value = value;
    result->next = next;
    //@ close list(result, cons(value, tail));
    return result;
}

bool equals(struct node *n1, struct node *n2)
    //@ requires list(n1, ?xs1) &*& list(n2, ?xs2);
    //@ ensures list(n1, xs1) &*& list(n2, xs2) &*& result == (xs1 == xs2);
{
    //@ open list(n1, xs1);
    //@ open list(n2, xs2);
    bool result = false;
    if (n1 == 0)
        result = n2 == 0;
    else if (n2 == 0)
        result = false;
    else if (n1->value != n2->value)
        result = false;
    else {
        bool tmp = equals(n1->next, n2->next);
        result = tmp;
    }
    //@ close list(n1, xs1);
    //@ close list(n2, xs2);
    return result;
}

void dispose(struct node *l)
    //@ requires list(l, _);
    //@ ensures true;
{
    //@ open list(l, _);
    if (l != 0) {
        struct node *next = l->next;
        free(l);
        dispose(next);
    }
}

/*@

predicate_family mapfunc(void *mapfunc)(void *data, list<int> in, list<int> out, any info);

@*/

typedef int mapfunc(void *data, int x);
    //@ requires mapfunc(this)(data, ?in, ?out, ?info) &*& in != nil &*& x == head(in);
    //@ ensures mapfunc(this)(data, tail(in), list_add(out, result), info);

struct node *map(struct node *list, mapfunc *f, void *data)
    //@ requires list(list, ?xs) &*& is_mapfunc(f) == true &*& mapfunc(f)(data, xs, ?out, ?info);
    //@ ensures list(list, xs) &*& list(result, ?ys) &*& mapfunc(f)(data, nil, append(out, ys), info);
{
    //@ open list(list, xs);
    if (list == 0) {
        //@ close list(list, xs);
        //@ close list(0, nil);
        //@ append_nil(out);
        return 0;
    } else {
        int fvalue = f(data, list->value);
        struct node *fnext = map(list->next, f, data);
        //@ assert list(fnext, ?ftail);
        //@ close list(list, xs);
        struct node *result = cons(fvalue, fnext);
        //@ append_add(out, fvalue, ftail);
        return result;
    }
}

/*@

fixpoint list<int> plusOne(list<int> xs) {
    switch (xs) {
        case nil: return nil;
        case cons(h, t): return cons<int>(h + 1, plusOne(t));
    }
}

predicate_family_instance mapfunc(plusOne)(void *data, list<int> in, list<int> out, list<int> info) =
    plusOne(info) == append(out, plusOne(in));

@*/

int plusOne(void *data, int x) //@ : mapfunc
    //@ requires mapfunc(plusOne)(data, ?in, ?out, ?info) &*& in != nil &*& x == head(in);
    //@ ensures mapfunc(plusOne)(data, tail(in), list_add(out, result), info);
{
    //@ assume_is_int(x);
    if (x == 2147483647) abort();
    //@ open mapfunc(plusOne)(data, in, out, ?info_);
    //@ append_add(out, x + 1, plusOne(tail(in)));
    //@ switch (in) { case nil: case cons(h, t): }
    //@ close mapfunc(plusOne)(data, tail(in), list_add(out, x + 1), info_);
    return x + 1;
}

int main()
    //@ requires true;
    //@ ensures true;
{
    struct node *l = 0;
    //@ close list(0, nil);
    l = cons(3, l);
    l = cons(2, l);
    l = cons(1, l);
    //@ close mapfunc(plusOne)(0, cons(1, cons(2, cons(3, nil))), nil, cons(1, cons(2, cons(3, nil))));
    struct node *l2 = map(l, plusOne, 0);
    //@ open mapfunc(plusOne)(0, nil, ?ys, _);
    struct node *l3 = 0;
    //@ close list(0, nil);
    l3 = cons(4, l3);
    l3 = cons(3, l3);
    l3 = cons(2, l3);
    bool tmp = equals(l2, l3);
    //@ append_nil(ys);
    assert(tmp);
    dispose(l);
    dispose(l2);
    dispose(l3);
    return 0;
}