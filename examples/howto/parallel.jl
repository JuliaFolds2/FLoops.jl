# # How to write _X_ in parallel.

using FLoops

using LiterateTest                                                     #src
using Test                                                             #src

# ## In-place mutation
#
# Mutable containers can be allocated in the `init` expressions
# (`zeros(3)` in the example below):

@test begin
    local ys  # hide
    @floop for x in 1:10
        xs = [x, 2x, 3x]
        @reduce() do (ys = zeros(3); xs)
            ys .+= xs
        end
    end
    ys
end == [55, 110, 165]

# Mutating objects allocated in the `init` expressions is not data
# race because each basecase "owns" such mutable objects.  However, it
# is incorrect to mutate objects created outside `init` expressions.
#
# See also: [What is the difference of `@reduce` and `@init` to the approach
# using `state[threadid()]`?](@ref faq-state-threadid)
#
# !!! note
#
#     Technically, it is correct to mutate objects in the loop body if
#     the objects are protected by a lock.  However, it means that the
#     code block protected by the lock can only be executed by a
#     single task.  For efficient data parallel loops, it is highly
#     recommended to use **non**-thread-safe data collection (i.e., no
#     lock) and construct the `@reduce` block that efficiently merge
#     two mutable objects.

# ### INCORRECT EXAMPLE

# This example has data race because the array `ys0` is shared across
# all base cases and mutated in parallel.

ys0 = zeros(3)
@dedent let
    @floop for x in 1:10
        xs = [x, 2x, 3x]
        @reduce() do (ys = ys0; xs)
            ys .+= xs
        end
    end
end

# ## [Data race-free reuse of mutable objects using private variables](@id private-variables)
#
# To avoid allocation for each iteration, it is useful to pre-allocate mutable
# objects and reuse them. We can use [`@init`](@ref) macro to do this in a
# data race-free ("thread-safe") manner:

@test begin
    local ys  # hide
    @floop for x in 1:10
        @init xs = Vector{typeof(x)}(undef, 3)
        xs .= (x, 2x, 3x)
        @reduce() do (ys = zeros(3); xs)
            ys .+= xs
        end
    end
    ys
end == [55, 110, 165]

# See also: [What is the difference of `@reduce` and `@init` to the approach
# using `state[threadid()]`?](@ref faq-state-threadid)
