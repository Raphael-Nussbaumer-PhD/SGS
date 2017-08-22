clear all;

% General setting
parm.k.covar.model = 'exponential';
parm.k.covar.azimuth = 0;
parm.k.covar.c0 = 1;
parm.k.covar.alpha = 1;
parm.seed_path = 0;
parm.seed_search = 'default';


parm.k.covar.range0 = [15 15];
parm.k.wradius = 1;
parm.mg = 1;
nx = 2^6+1; % no multigrid
ny = 2^6+1;
parm.k.nb = 20;


vario = {'exponential', 'gaussian', 'spherical', 'hyperbolic', 'k-bessel', 'cardinal sine'};

% True
[Y, X]=ndgrid(1:nx,1:ny);
XY = [Y(:) X(:)];
for v=1:numel(vario)
    covar=parm.k.covar;
    covar(1).model = vario{v};
    covar = kriginginitiaite(covar);
    DIST = squareform(pdist(XY*covar.cx));
    CY_true{v} = kron(covar.g(DIST), covar.c0);
end
err_frob_fx = @(CY,v) sqrt(sum((CY(:)-CY_true{v}(:)).^2)) / sum((CY_true{v}(:).^2));


% Simulation
N = 3;
tic
parpool(6)
parfor v=1:numel(vario)
    parm1=parm;
    parm1.gen.covar.model = vario{v};
    CY=repmat({nan(ny*nx,nx*ny,2)},N,1);
    eta{v}=cell(N,1);
    nn=cell(N,1);
    for n=1:(2^(N-1))
        vec = de2bi(n-1,N);
        CY{1}(:,:,vec(1)+1) = full(SGS_varcovar(nx,ny,parm1));
        eta{v}{1} = [eta{v}{1}; err_frob_fx(CY{1}(:,:,vec(1)+1),v)];
        nn{1} = [nn{1}; 2^(1-1)];
        i=1;
        while (vec(i)==1)
            CY{i+1}(:,:,vec(i+1)+1) = mean(CY{i},3);
            eta{v}{i+1} = [eta{v}{i+1}; err_frob_fx(CY{i+1}(:,:,vec(i+1)+1),v)];
            nn{i+1} = [nn{i+1}; 2^(i)];
            i=i+1;
        end
        disp(['N: ' num2str(n) ])
    end
    %save(['frobenium_',vario{v},'_20_512_MG'])
end
toc

% save(['./cst_path_paper/frobenium_65n_20k_512N_noMG'],'eta','vario','nn','parm','nx','ny');

boxplot(cell2mat(eta{v}),cell2mat(nn),'Orientation','horizontal');


%%
parm.mg =1;
parm.seed_path = Inf;
N = 3;

parm.gen.covar.model = 'spherical';
CY=repmat({nan(ny*nx,nx*ny,2)},N,1);
eta{v}=cell(N,1);
nn=cell(N,1);
for n=1:(2^(N-1))
    vec = de2bi(n-1,N);
    CY{1}(:,:,vec(1)+1) = full(SGS_varcovar(nx,ny,parm));
    eta{v}{1} = [eta{v}{1}; err_frob_fx(CY{1}(:,:,vec(1)+1),v)];
    nn{1} = [nn{1}; 2^(1-1)];
    i=1;
    while (vec(i)==1)
        CY{i+1}(:,:,vec(i+1)+1) = mean(CY{i},3);
        eta{v}{i+1} = [eta{v}{i+1}; err_frob_fx(CY{i+1}(:,:,vec(i+1)+1),v)];
        nn{i+1} = [nn{i+1}; 2^(i)];
        i=i+1;
    end
    disp(['N: ' num2str(n) ])
end

hold on;
boxplot(cell2mat(eta{v}),cell2mat(nn),'Orientation','horizontal');





