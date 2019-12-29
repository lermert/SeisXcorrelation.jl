export compute_reference_xcorr, robust_reference_xcorr, remove_nanandzerocol
using Statistics
"""
compute_reference_xcorr(InputDict::Dict)

compute and save reference cross-correlation function.
"""
function compute_reference_xcorr(InputDict::Dict)
    # computing reference xcorr
    #===
    Workflow:
    1. get timestamps between ref_starttime and ref_endtime and get path to xcorr files
    Note: only this process, you need to search among diferent years.
    2. At the first time, compute linear stack of all time stamp and sum up all of them
    3. iterate using selective stack
    4. save final reference dict
    ===#

    Output_rootdir = join(split(InputDict["basefiname"],"/")[1:end-3], "/") #.../OUTPUT
	refYear = split(InputDict["basefiname"],"/")[end-2]
	refname = Output_rootdir*"/reference_xcorr_for$(refYear).jld2" # this is fixed in the SeisXcorrelation/pstack.

	ref_dict_out = Dict()

	# get xcorr path between ref_starttime and ref_endtime
	ref_st =InputDict["ref_starttime"]
	ref_et =InputDict["ref_endtime"]
	ref_styear = Dates.Year(ref_st).value
	ref_etyear = Dates.Year(ref_et).value

	if InputDict["ref_iter"] < 1 error("ref_iter should be more than 1."); end

	for riter = 1:InputDict["ref_iter"] # iterate over "ref_iter" when using selective ref
		for year = ref_styear:ref_etyear
			println(riter)

			corrname  = Output_rootdir*"/$(year)"*"/cc/$(year)_xcorrs"
			f = jldopen(corrname*".jld2");
			tslist = f["info/timestamplist"] # base xcorr file
			close(f)

			ref_dicts = []

			if riter == 1
				# first iteration should be stack="linear" because no reference
				ref_dicts = pmap(t->map_reference(t, InputDict, corrname, stackmode="linear"), tslist)
				#NOTE: ref_dicts has fillstation pass key including channels

				# collect all references into one dictionary at first iteration

				#------------------------------------------------------------#
				#DEBUG:
				#Init reference has a bug: this should be also over the year
				#------------------------------------------------------------#

				ref_dict_out_init = Dict()

				# Consider station pairs through the time regardless of channel
				# e.g. 1st day:NC.PDA..EHZ.NC.PCA..EHZ.  2nd day: NC.PCA..SHZ.NC.PDA..EHZ.
				# this case above we regard it as same station pair so that stacking togeter with "NC.PDA-NC.PCA-ZZ".

				for i=1:length(ref_dicts)
					for stnkey in keys(ref_dicts[i])
						xcorr_temp = ref_dicts[i][stnkey]
						stnkey = xcorr_temp.name
						stn1 = join(split(stnkey, ".")[1:2], ".")
						stn2 = join(split(stnkey, ".")[5:6], ".")
						comp = xcorr_temp.comp
						nochan_stnpair = stn1*"-"*stn2*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ
						nochan_stnpairrev = stn2*"-"*stn1*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ

						if haskey(ref_dict_out_init, nochan_stnpair)
							if !isempty(ref_dicts[i][stnkey].corr)
			 					ref_dict_out_init[nochan_stnpair].corr .+= ref_dicts[i][stnkey].corr
							end
				 		elseif haskey(ref_dict_out_init, nochan_stnpairrev)
							if !isempty(ref_dicts[i][stnkey].corr)
								ref_dict_out_init[nochan_stnpair].corr .+= reverse(ref_dicts[i][stnkey].corr, dims=1)
							end
						else
							# add new station pair into ref_dict_out with stnpair (reversed stnpair in other time steps is taken into account above.)
							ref_dict_out_init[nochan_stnpair] = deepcopy(ref_dicts[i][stnkey])
						end
					end
				end

				#
				# for i=1:length(ref_dicts)
				# 	for stnpair in keys(ref_dicts[i])
				# 		if haskey(ref_dict_out_init, stnpair)
				# 			ref_dict_out_init[stnpair].corr .+= ref_dicts[i][stnpair].corr
				# 		else
				# 			# add new station pair into ref_dict_out
				# 			ref_dict_out_init[stnpair] = deepcopy(ref_dicts[i][stnpair])
				# 		end
				# 	end
				# end

				# save initial reference
				f_out = jldopen(refname, "w")
				for stnpair in keys(ref_dict_out_init)
					f_out[stnpair] = ref_dict_out_init[stnpair]
				end
				close(f_out)

			else
				#allow either linear stack or selective stack
				ref_dicts = pmap(t->map_reference(t, InputDict, corrname,
							stackmode=InputDict["stackmode"], reference=refname), tslist)
			end

			#println(sizeof(ref_dicts))

			# merge all timestamp
			#println("debug1")
			#println(length(ref_dicts))

			for i=1:length(ref_dicts)
				#println(keys(ref_dicts[i]))
				for stnkey in keys(ref_dicts[i])
					xcorr_temp = ref_dicts[i][stnkey]
					stnkey = xcorr_temp.name
					stn1 = join(split(stnkey, ".")[1:2], ".")
					stn2 = join(split(stnkey, ".")[5:6], ".")
					comp = xcorr_temp.comp
					nochan_stnpair = stn1*"-"*stn2*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ
					nochan_stnpairrev = stn2*"-"*stn1*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ
					if haskey(ref_dict_out, nochan_stnpair)
						if !isempty(ref_dicts[i][stnkey].corr)
							ref_dict_out[nochan_stnpair].corr .+= ref_dicts[i][stnkey].corr
							if riter == 1
								ref_dict_out[nochan_stnpair].misc["numofstack"] += 1
							end
						end
					elseif haskey(ref_dict_out, nochan_stnpairrev)
						if !isempty(ref_dicts[i][stnkey].corr)
							ref_dict_out[nochan_stnpair].corr .+= reverse(ref_dicts[i][stnkey].corr, dims=1)
							if riter == 1
								ref_dict_out[nochan_stnpair].misc["numofstack"] += 1
							end
						end
					else
						# add new station pair into ref_dict_out with stnpair (reversed stnpair in other time steps is taken into account above.)
						ref_dict_out[nochan_stnpair] = deepcopy(ref_dicts[i][stnkey])
						if riter == 1
							ref_dict_out[nochan_stnpair].misc["numofstack"] = 1
						end
					end

					# if haskey(ref_dict_out, stnpair)
					# 	ref_dict_out[stnpair].corr .+= ref_dicts[i][stnpair].corr
					# 	if riter == 1
					# 		ref_dict_out[stnpair].misc["numofstack"] += 1
					# 	end
					# else
					# 	# initiate new station pair CorrData into ref_dict_out
					# 	ref_dict_out[stnpair] = deepcopy(ref_dicts[i][stnpair])
					# 	if riter == 1
					# 		ref_dict_out[stnpair].misc["numofstack"] = 1
					# 	end
					# end
				end
			end

		end
	end

	# save final reference (this works even if riter = 1)
	f_out = jldopen(refname, "w")
	for stnpair in keys(ref_dict_out)
		# #Debug
		# println(stnpair)
		if InputDict["IsNormalizedReference"]
			#normalized reference amplitude by numofstack
			ref_dict_out[stnpair].corr ./= ref_dict_out[stnpair].misc["numofstack"]
		end
		#rr = ref_dict_out[stnpair]
		#println(rr.corr[100:110,1])
		f_out[stnpair] = ref_dict_out[stnpair]
	end
	close(f_out)

	# output reference status
	numofstackall = []
	for key = keys(ref_dict_out)
		push!(numofstackall, ref_dict_out[key].misc["numofstack"])
	end
	numofrefchannel = length(keys(ref_dict_out))
	maxnumofstack = maximum(numofstackall)
	minnumofstack = minimum(numofstackall)
	meannumofstack = mean(numofstackall)
	println("#---Reference stacking summary---#")
	println("Number of reference xcorr function: $(numofrefchannel)")
	println("Maximum num of stack: $(maxnumofstack)")
	println("Minimum num of stack: $(minnumofstack)")
	println("Mean num of stack   : $(meannumofstack)")
	println("#---reference xcorr is successfully saved---#\n$(refname)\n#--------------------------------------------#.")
end

"""
    map_reference(tstamp::String, InputDict::Dict, corrname::String;, stack::String="linear", reference::String="", thresh::Float64=-1.0)

Stack all cross-correlation functions for all given station pairs to generate a reference cross-correlation.

# Arguments
- `tstamp::String`    :
- `InputDict::Dict` : input dictionary
- `corrname::String,`    : Input base file name
- `phase_smoothing::Float64`    : Level of phase_smoothing (0 for linear stacking)
- `stack::String`     : "selective" for selective stacking and "linear" for linear stacking
- `reference::String`    : Path to the reference used in selective stacking
- `thresh::Float64`     : Threshold used for selective stacking

# Output
- `foname.jld2`    : contains arrays of reference cross-correlations for each station pair
"""
function map_reference(tstamp::String, InputDict::Dict, corrname::String; stackmode::String="linear", reference::String="")
    # hold reference xcorrs in memory and write all at once
	ref_dict = Dict()

	# if this time stamp is not in the ref_start and end time, skip stacking
	y, jd = parse.(Int64, split(tstamp, ".")[1:2])
	m, d  = j2md(y,jd)
	curdate=DateTime(y, m, d)

	if curdate >= InputDict["ref_starttime"] && curdate <= InputDict["ref_endtime"]
		#this time stamp is taken into account to stack

	    # read unstacked xcorrs for each time stamp
	    f_cur = jldopen(corrname*".$tstamp.jld2")
	    grp = try
			f_cur[tstamp] # xcorrs
		catch
			ref_dict = Dict()
			return ref_dict
		end

	    println("$tstamp")

	    # iterate over station pairs
	    for pair in sort(keys(grp))
	        # Implemented -> TODO: use only unique station pairings when creating references. Currently no guarantee of uniqueness (reverse can exist)
	        # load xcorr
	        xcorr = try grp[pair] catch; continue end

	        #remove_nan!(xcorr)
	        # stack xcorrs over length of CorrData object using either "selective" stacking or "linear" stacking

			if InputDict["filter"] !=false
				xcorr = bandpass(xcorr.corr, InputDict["filter"][1], InputDict["filter"][2], xcorr.fs, corners=4, zerophase=false)
			end

			# load reference
			if !isempty(reference)

				stnkey = xcorr.name
				stn1 = join(split(stnkey, ".")[1:2], ".")
				stn2 = join(split(stnkey, ".")[5:6], ".")
				comp = xcorr.comp
				nochan_stnpair = stn1*"-"*stn2*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ
				nochan_stnpairrev = stn2*"-"*stn1*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ

				f_exref = jldopen(reference)

				# NOTE: the try catch below keeps consitent to the order of station pairs between current and reference
				ref = try
						f_exref[nochan_stnpair]
					  catch
							try
								f_exref[nochan_stnpairrev]
							catch
								#println("debug: add new from second with linear.")
								stackmode="linear"
							end
					  end

				close(f_exref)
				if InputDict["filter"] !=false
					ref   = bandpass(ref.corr, InputDict["filter"][1], InputDict["filter"][2], xcorr.fs, corners=4, zerophase=false)
				end
			end

	        if stackmode=="selective"

				# avoid NaN in xcorr
				nancols = any(isnan.(xcorr.corr), dims=1)
				xcorr.corr = xcorr.corr[:, vec(.!nancols)]
				xcorr.t = xcorr.t[vec(.!nancols)]

	            xcorr, rmList = selective_stacking(xcorr, ref, InputDict)
	        elseif stackmode=="linear"
				#linear stacking
				# avoid NaN in xcorr
				nancols = any(isnan.(xcorr.corr), dims=1)
				xcorr.corr = xcorr.corr[:, vec(.!nancols)]
				xcorr.t = xcorr.t[vec(.!nancols)]

				if isempty(xcorr.corr) continue; end
	            stack!(xcorr, allstack=true)
			else
				error("stack mode $(stackmode) not defined.")
	        end

	        # stack xcorrs if they have a key, assign key if not
	        if haskey(ref_dict, pair)
	            ref_dict[pair].corr .+= xcorr.corr
	        else
	            ref_dict[pair] = deepcopy(xcorr)
	        end
	    end

	    close(f_cur) # current xcorr file

	end

    return ref_dict
end

#=======================================================================#
#=======================================================================#
#=======================================================================#


"""
robust_reference_xcorr(InputDict::Dict)

compute and save reference cross-correlation function using robust stack.
"""
function robust_reference_xcorr(InputDict::Dict)
    # computing reference xcorr
    #===
    Workflow:
    1. get timestamps between ref_starttime and ref_endtime and get path to xcorr files
    Note: only this process, you need to search among diferent years.
    2. Compute day to day robust stack and store it into ref_corrdata
    3. Compute robust stack over reference period
    4. save final reference dict
    ===#

    Output_rootdir = join(split(InputDict["basefiname"],"/")[1:end-3], "/") #.../OUTPUT
	refYear = split(InputDict["basefiname"],"/")[end-2]
	refname = Output_rootdir*"/reference_xcorr_for$(refYear).jld2" # this is fixed in the SeisXcorrelation/pstack.

	ref_dict_out = Dict() # this contains {"stationpair" => CorrData}

	# get xcorr path between ref_starttime and ref_endtime
	ref_st =InputDict["ref_starttime"]
	ref_et =InputDict["ref_endtime"]
	ref_styear = Dates.Year(ref_st).value
	ref_etyear = Dates.Year(ref_et).value

	# collect all references into one dictionary at first iteration
	ref_dict_dailystack = Dict()

	for year = ref_styear:ref_etyear

		corrname  = Output_rootdir*"/$(year)"*"/cc/$(year)_xcorrs"
		f = jldopen(corrname*".jld2");
		tslist = f["info/timestamplist"] # base xcorr file
		close(f)

		ref_dicts = []

		# first iteration should be stack="linear" because no reference
		ref_dicts = pmap(t->map_robustreference(t, InputDict, corrname), tslist)
		#NOTE: ref_dicts has fillstation pass key including channels

		# Consider station pairs through the time regardless of channel
		# e.g. 1st day:NC.PDA..EHZ.NC.PCA..EHZ.  2nd day: NC.PCA..SHZ.NC.PDA..EHZ.
		# this case above we regard it as same station pair so that stacking togeter with "NC.PDA-NC.PCA-ZZ".

		for i=1:length(ref_dicts)
			for stnkey in keys(ref_dicts[i])
				xcorr_temp = ref_dicts[i][stnkey]
				stnkey = xcorr_temp.name
				stn1 = join(split(stnkey, ".")[1:2], ".")
				stn2 = join(split(stnkey, ".")[5:6], ".")
				comp = xcorr_temp.comp
				nochan_stnpair = stn1*"-"*stn2*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ
				nochan_stnpairrev = stn2*"-"*stn1*"-"*comp # e.g. NC.PDR-NC.PHA-ZZ

				if haskey(ref_dict_dailystack, nochan_stnpair)
					if !isempty(ref_dicts[i][stnkey].corr)
	 					ref_dict_dailystack[nochan_stnpair].corr = hcat(ref_dict_dailystack[nochan_stnpair].corr,
						 ref_dicts[i][stnkey].corr)
					end
		 		elseif haskey(ref_dict_dailystack, nochan_stnpairrev)
					if !isempty(ref_dicts[i][stnkey].corr)
						ref_dict_dailystack[nochan_stnpair].corr = hcat(ref_dict_dailystack[nochan_stnpair].corr,
						 reverse(ref_dicts[i][stnkey].corr, dims=1))
					end
				else
					# add new station pair into ref_dict_out with stnpair (reversed stnpair in other time steps is taken into account above.)
					ref_dict_dailystack[nochan_stnpair] = deepcopy(ref_dicts[i][stnkey])
				end
			end
		end
	end


	# save final reference (this works even if riter = 1)
	f_out = jldopen(refname, "w")
	for stnpair in keys(ref_dict_dailystack)
		# #Debug
		#println(ref_dict_dailystack[stnpair])
		#@show any(isnan.(ref_dict_dailystack[stnpair].corr), dims=1)
		f_out[stnpair] = robuststack!(ref_dict_dailystack[stnpair])
		#@show any(isnan.(f_out[stnpair].corr), dims=1)

		# println(ref_dict_dailystack[stnpair])

	end
	close(f_out)

	# output reference status
	println("#---robust stacking for reference xcorr is successfully saved---#\n$(refname)\n#--------------------------------------------#.")
	return nothing
end

"""
    map_robustreference(tstamp::String, InputDict::Dict, corrname::String)

Robust stack cross-correlation functions for all given station pairs to generate a reference cross-correlation.

# Arguments
- `tstamp::String`    :
- `InputDict::Dict` : input dictionary
- `corrname::String,`    : Input base file name

# Output
- `foname.jld2`    : contains arrays of reference cross-correlations for each station pair
"""
function map_robustreference(tstamp::String, InputDict::Dict, corrname::String)
    # hold reference xcorrs in memory and write all at once
	ref_dict = Dict()

	# if this time stamp is not in the ref_start and end time, skip stacking
	y, jd = parse.(Int64, split(tstamp, ".")[1:2])
	m, d  = j2md(y,jd)
	curdate=DateTime(y, m, d)

	if curdate >= InputDict["ref_starttime"] && curdate <= InputDict["ref_endtime"]
		#this time stamp is taken into account to stack

	    # read unstacked xcorrs for each time stamp
	    f_cur = jldopen(corrname*".$tstamp.jld2")
	    grp = try
			f_cur[tstamp] # xcorrs
		catch
			ref_dict = Dict()
			return ref_dict
		end

	    println("$tstamp")

	    # iterate over station pairs
	    for pair in sort(keys(grp))
	        # Implemented -> TODO: use only unique station pairings when creating references. Currently no guarantee of uniqueness (reverse can exist)
	        # load xcorr
	        xcorr = try grp[pair] catch; continue end

	        #remove_nan!(xcorr)
	        # stack xcorrs over length of CorrData object using either "selective" stacking or "linear" stacking

			if InputDict["filter"] !=false
				xcorr = bandpass(xcorr.corr, InputDict["filter"][1], InputDict["filter"][2], xcorr.fs, corners=4, zerophase=false)
			end

			# nancols = any(isnan.(xcorr.corr), dims=1)
			# xcorr.corr = xcorr.corr[:, vec(.!nancols)]

			xcorr.corr , nanzerocol = remove_nanandzerocol(xcorr.corr)
			xcorr.t = xcorr.t[nanzerocol]

			if isempty(xcorr.corr)
				#skip this pair as there is no cc function
				continue;
			end
			# @show any(isnan.(xcorr.corr), dims=1)
			# debugxcorr = deepcopy(xcorr)

			# println(vec(.!nancols))
			# println(xcorr.corr)

			robuststack!(xcorr)
			#
			# print("nancheck:")
			# @show any(isnan.(xcorr.corr), dims=1)

			if any(x-> x == true, any(isnan.(xcorr.corr), dims=1))
				println("found nan in xcorr.corr.")
				#@show(debugxcorr.corr)
				robuststack_debug!(debugxcorr)

				#println(xcorr.corr)
				error("Nan found in stacked trace. abort")
			end

			# stack xcorrs if they have a key, assign key if not
			if haskey(ref_dict, pair)
				ref_dict[pair].corr .+= xcorr.corr
			else
				ref_dict[pair] = deepcopy(xcorr)
			end

	    end

	    close(f_cur) # current xcorr file

	end

    return ref_dict
end


"""
	remove_nancol(A::AbstractArray)

Remove column (i.e. trace) which has NaN.
"""
function remove_nanandzerocol(A::AbstractArray)

	N = size(A, 2)
	nancol = ones(Int64, N)
	for i = 1:N
		if any(isnan.(A[:, i])) || all(iszero, A[:,i])
			# this has NaN in its column
			nancol[i] = 0
		end
	end

	nancol=convert.(Bool, nancol)
	return A[:, nancol], nancol

end
#
#
# """
#   robuststack_debug(A)
# Performs robust stack on array `A`.
# Follows methods of Pavlis and Vernon, 2010.
# # Arguments
# - `A::AbstractArray`: Time series stored in columns.
# - `ϵ::AbstractFloat`: Threshold for convergence of robust stack.
# - `maxiter::Int`: Maximum number of iterations to converge to robust stack.
# """
# function robuststack_debug(A::AbstractArray{T};ϵ::AbstractFloat=Float32(1e-6),
#                      maxiter::Int=10) where T <: AbstractFloat
#     N = size(A,2)
#     Bold = median(A,dims=2)
#     w = Array{T}(undef,N)
#     r = Array{T}(undef,N)
#     d2 = Array{T}(undef,N)
#
#     # do 2-norm for all columns in A
#     for ii = 1:N
#         d2[ii] = norm(A[:,ii],2)
#     end
#
#     BdotD = sum(A .* Bold,dims=1)
#
#     for ii = 1:N
#
# 		@show BdotD[ii]
# 		@show Bold
# 		@show A[:,ii]
#
#         r[ii] = norm(A[:,ii] .- (BdotD[ii] .* Bold),2)
#         w[ii] = abs(BdotD[ii]) ./ d2[ii] ./ r[ii]
#
# 		@show r[ii]
# 		@show w[ii]
#
#     end
#
#     w ./= sum(w)
#
# 	@show r
#
# 	@show d2
#
#  	@show w
#
# 	@show A
#
#     Bnew = mean(A,weights(w),dims=2)
# 	@show Bnew
#
#     # check convergence
#     ϵN = norm(Bnew .- Bold,2) / (norm(Bnew,2) * N)
#     Bold = Bnew
#     iter = 0
#     while (ϵN > ϵ) && (iter <= maxiter)
#         BdotD = sum(A .* Bold,dims=1)
#
#         for ii = 1:N
#             r[ii] = norm(A[:,ii] .- (BdotD[ii] .* Bold),2)
#             w[ii] = abs(BdotD[ii]) ./ d2[ii] ./ r[ii]
#         end
#         w ./= sum(w)
#
#         Bnew = mean(A,weights(w),dims=2)
#
#         # check convergence
#         ϵN = norm(Bnew .- Bold,2) / (norm(Bnew,2) * N)
#         Bold = Bnew
#         iter += 1
#     end
#     return Bnew
# end
# robuststack_debug!(C::CorrData;ϵ::AbstractFloat=eps(Float32)) =
#        (C.corr = robuststack_debug(C.corr,ϵ=ϵ); C.t = C.t[1:1]; return C)
# robuststack_debug(C::CorrData;ϵ::AbstractFloat=eps(Float32))  =
#        (U = deepcopy(C); U.corr = robuststack_debug(U.corr,ϵ=ϵ); U.t = U.t[1:1];
#        return U)
