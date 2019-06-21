using SeisIO, Noise, JLD2, Distributed, Dates

include("../../src/SeisXcorrelation.jl")
include("../../src/pairing.jl")

# input parameters
InputDict = Dict( "finame"     => "/Volumes/Elements/inputData/BPnetwork_Jan03_joined.jld2",
                  "basefoname"     => "testData.jld2",
                  "freqmin"    => 0.1,
                  "freqmax"    => 9.9,
                  "fs"         => 20.0,
                  "cc_len"     => 3600,
                  "cc_step"    => 1800,
                  "corrtype"   => ["xcorr", "xchancorr", "acorr"],
                  "corrorder"  => 1,
                  "maxtimelag" => 100.0,
                  "allstack"   => false)

# read data from JLD2
data = jldopen(InputDict["finame"])
# read station and time stamp lists
stlist = data["info/stationlist"][:]
tstamplist = data["info/DLtimestamplist"][:]

# generate station pairs
if InputDict["corrorder"] == 1
    station_pairs = generate_pairs(stlist)
    # sort station pairs into autocorr, xcorr, and xchancorr
    sorted_pairs = sort_pairs(station_pairs)
else
    station_pairs = data["info/corrstationlist"]["xcorr"]
    # concat correlated station names
    station_pairs = station_pairs[1, :] .* '.' .* station_pairs[2, :]
    corrstationlist = generate_pairs(station_pairs)
    # sort correlated pairs into autocorr, xcorr, and xchancorr
    # c2 and c3 will iterate only over xcorr
    sorted_pairs = sort_pairs(corrstationlist)
end

# create output file and save station and pairing information in JLD2
jldopen(InputDict["basefoname"], "w") do file
    file["info/timestamplist"]   = tstamplist;
    file["info/stationlist"]     = stlist;
    file["info/corrstationlist"] = sorted_pairs;
    file["info/tserrors"]        = []
end

# TODO make sure tserrors are actually written to file
for i=1:length(tstamplist)
    st = time()
    InputDict["foname"] = "testData$i.jld2"
    errors = seisxcorrelation(tstamplist[i], stlist, InputDict)

    jldopen(InputDict["basefoname"], "a+") do file
        append!(file["info/tserrors"], errors)
    end
    et = time()
    println("$(tstamplist[i]) took $(et-st) seconds.")
end
close(data)
println("Successfully completed cross-correlation and saved to $(InputDict["foname"])")
#pmap(x -> seisxcorrelation(x, finame, foname, corrtype, corrorder, maxtimelag, freqmin, freqmax, fs, cc_len, cc_step), [tstamplist[1]])
