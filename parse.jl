export toOdeFile, fromOdeFile, parseOutputFile

newline = os[OS_NAME].newline

@doc doc"""
Function for writing a Model-instance to an .ode file

    toOdeFile(ModelInstance)

...will write the model instance to an ode file with the name ModelInstance.name
"""->
function toOdeFile(M::Model)
    file = "#" * M.name * newline * "#generated using XPPjl" * newline * newline * "#ODEs:$newline"
    for r in M.odes
        file *= r[1] * "\'=" * r[2] * newline
    end
    #Algebraic equation automatically also auxvars
    file *= newline * newline * "#Algebraic and auxilliary equations:" * newline
    for a in M.aux
        file *=  a[1] * "=" * a[2] * newline
        file *= "aux " * a[1] * "=" * a[1] * newline
    end
    #Parameters
    file *= newline * newline * "#Parameters:\n"
    for p in M.pars
        file *= "p " * p[1] * "=" * string(p[2]) *newline
    end
    #Initials
    file *= newline * newline * "#Initials:\n"
    for i in M.init
        file *= "init " * i[1] * "=" * string(i[2]) *newline
    end
    #Settings
    file *= newline * newline * "#Settings:\n"
    for s in M.spec
        file *= "@ " * s[1] * "=" * string(s[2]) *newline
    end
    file *= "done" * newline
    f = open(M.name, "w")
    write(f, file)
    close(f)
end

@doc doc"""
High-level routine for generating a model instance from an existing .ode-file

    ModelName = fromOdeFile(\"odeFilenameAsString.ode\")

Syntax requirements:

    - odes are specified with ' instead of dVar/dt

    - parameters are specified with the 'p '-prefix

    - settings are specified with the '@ '-prefix

    - initial conditions are specified with the 'init '-prefix

    - every line can only contain a single specification, i.e. no concatentation of multiple parameter/initial/setting specifiactions in a single line

    - auxilliary variables are ignored unless specified as algebraic variables!
"""->
function fromOdeFile(filename::String)
     f = open(filename)
     name = split(filename, ".ode")[1]
     M = parseOdeFile(f, name)
     close(f)
     return(M)
end

@doc doc"""
Function for parsing .ode files that obey the following rules:

    - odes are specified with \' instead of dVar/dt

    - parameters are specified with the 'p '-prefix

    - settings are specified with the '@ '-prefix

    - initial conditions are specified with the 'init '-prefix

    - every line can only contain a single specification, i.e. no concatentation of multiple parameter/initial/setting specifiactions in a single line

    - auxilliary variables are ignored unless specified as algebraic variables!
"""->
function parseOdeFile(f::IOStream, modelname::String)
    odes = Dict()
    init = Dict()
    pars = Dict()
    aux = Dict()
    spec = Dict()
    vars = Any[]
    for l in eachline(f)
        l = split(string(l), newline)[1];
        if length(l) < 3 || l[1] == '#' || contains(l, "aux ")  || contains(l, "done")
            #comment or empty line: do nothing
            #both auxilliary and algebraic equation treated as the same
        elseif l[1:2] == "p "
            #parameter
            parts = split(l, "=")
            name = parts[1][3:end]
            value = float(parts[2])
            pars[name] = value
        elseif l[1:5] == "init "
            #initial condition
            parts = split(l, "=")
            name = parts[1][6:end]
            value = float(parts[2])
            init[name] = value
        elseif l[1:2] == "@ "
            #method specification
            parts = split(l, "=")
            name = parts[1][3:end]
            value = parts[2]
            spec[name] = value
        elseif split(l, "=")[1][end] == '\''
            #variable
            parts = split(l, "=")
            name = parts[1][1:end-1]
            push!(vars, name)
            value = parts[2]
            odes[name] = value
        else
            #auxilliary variable
            parts = split(l, "=")
            name = parts[1]
            push!(vars, name)
            value = parts[2]
            aux[name] = value
        end
    end
    M = Model(odes, init, pars, modelname, aux, spec, vars)
    return(M)
end

@doc doc"""
Parse output file and store it as new SimulationData-instance in the Model.sims-dict

    SimulationDataInstance = parseOutputFile(file-IOstream, ModelInstance)
"""->
function parseOutputFile(f::IOStream, M::Model, name = false)
    if name == false
        #Get the new key for the dict
        k = length(M.sims) + 1
    else
        #Overwrite the last simulation
        k = name
    end
    #Instantiate new SimulationData-structure
    M.sims[k] = SimulationData(M)
    #loop over lines in file
    for l in eachline(f)
        #Remove newline and space at the end of each line
        l = split(string(l), " \n")[1];
        #Split line to get data points
        pts = split(l, " ");
        #Loop over var-list & append to SimulationData.D-instance based on index
        for v in M.vars
            i = findfirst(M.vars, v)
            push!(M.sims[k].D[v], float(pts[i]))
        end
    end
    return(M)
end
