using QuickTypes

abstract AbstractToken{T}

immutable Prim{T} <: AbstractToken{T} end

@qtype Field{T}(
    inner::Prim{T}
  , ignore_init_whitespace::Bool=true
  , ignore_end_whitespace::Bool=true
  , quoted::Bool=false
  , quotechar::Char='"'
  , escapechar::Char='\\'
  , eofdelim::Bool=false
  , spacedelim::Bool=false
  , delim::Char=','
)

function tryparsenext{T}(f::Field{T}, str, i, len)
    R = Nullable{T}
    i > len && @goto error
    if f.ignore_init_whitespace
        while i <= len
            @inbounds c, ii = next(str, i)
            !iswhitespace(c) && break
            i = ii
        end
    end
    res, i = @chk1 tryparsenext(f.inner, str, i, len)

    i0 = i
    if f.ignore_end_whitespace
        while i <= len
            @inbounds c, ii = next(str, i)
            !iswhitespace(c) && break
            i = ii
        end
    end

    f.spacedelim && i > i0 && @goto done
    f.delim == '\t' && c == '\t' && @goto done

    if i > len
        if f.eofdelim
            @goto done
        else
            @goto error
        end
    end

    @inbounds c, ii = next(str, i)
    c != f.delim && @goto error # this better be the delim!!
    i = ii

    @label done
    return R(res), i

    @label error
    return R(), i
end

using Base.Test


@inline function tryparsenext{T<:Unsigned}(::Prim{T}, str, i, len)
    tryparsenext_base10(T,str, i, len, 20)
end

@inline function tryparsenext{T<:Signed}(::Prim{T}, str, i, len)
    R = Nullable{T}
    sign, i = @chk1 tryparsenext_sign(str, i, len)
    x, i = @chk1 tryparsenext_base10(T, str, i, len, 20)

    @label done
    return R(sign*x), i

    @label error
    return R(), i
end

@inline function tryparsenext(::Prim{Float64}, str, i, len)
    R = Nullable{Float64}
    f = 0.0
    sign, i = @chk1 tryparsenext_sign(str, i, len)
    x, i = @chk1 tryparsenext_base10(Int, str, i, len, 20)
    i > len && @goto done

    point, ii = next(str, i)
    point != '.' && @goto done
    y, i = @chk1 tryparsenext_base10_frac(str, ii, len, 16)
    f = y / 10^16

    @label done
    return R(sign*(x+f)), i

    @label error
    return R(), i
end

@inline function _substring(::Type{String}, str, i, j)
    str[i:j]
end

@inline function _substring(::Type{SubString}, str, i, j)
    SubString(str, i, j)
end

using WeakRefStrings
@inline function _substring(::Type{WeakRefString}, str, i, j)
    WeakRefString(pointer(str.data)+(i-1), (j-i+1))
end

@inline function tryparsenext{T<:AbstractString}(::Prim{T}, str, i, len, opts)
    R = Nullable{T}
    _, ii = @chk1 tryparsenext_string(str, i, len, opts.delim)

    @label done
    return R(_substring(T, str, i, ii-1)), ii

    @label error
    return R(), ii
end

# fallback to method which doesn't need options
@inline function tryparsenext(f, str, i, len, opts)
    tryparsenext(f, str, i, len)
end
